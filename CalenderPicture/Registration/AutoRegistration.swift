//
//  AutoRegistration.swift
//  CalenderPicture
//
//  写真ライブラリを見て、月の未登録の日にその日に撮った写真を1枚ずつ選び、クレヨン変換して登録する。
//  選ぶ順番: お気に入り → 主役（人・ペット・物）を切り抜ける写真 → 遅く撮った写真。スクリーンショットは使わない。
//

import Photos
import UIKit

/// 写真ライブラリの写真1枚の情報（選ぶ順番を決めるのに使う）
nonisolated struct PhotoCandidate: Equatable, Sendable {
    let id: String
    let day: DayKey
    let createdAt: Date
    let isFavorite: Bool
    let isScreenshot: Bool
}

nonisolated enum AutoPick {
    /// 1日あたり、主役が写っているかを調べる写真の数（多いと時間がかかる）
    static let maxChecksPerDay = 6

    /// 日ごとの候補を、選びたい順に並べる。スクリーンショットと `skipping` の日（登録済み）は除く
    static func candidatesByDay(_ photos: [PhotoCandidate], skipping: Set<DayKey>) -> [DayKey: [PhotoCandidate]] {
        let usable = photos.filter { !$0.isScreenshot && !skipping.contains($0.day) }
        return Dictionary(grouping: usable, by: \.day).mapValues { $0.sorted(by: isPreferred) }
    }

    /// お気に入りを先に、同じならあとに撮った写真を先に
    static func isPreferred(_ a: PhotoCandidate, over b: PhotoCandidate) -> Bool {
        if a.isFavorite != b.isFavorite { return a.isFavorite }
        return a.createdAt > b.createdAt
    }

    /// 候補（優先順）と、それぞれ主役が写っているかから選ぶ1枚。主役が写っていなければ先頭
    static func pick(_ candidates: [PhotoCandidate], hasSubject: [Bool]) -> PhotoCandidate? {
        zip(candidates, hasSubject).first { $0.1 }?.0 ?? candidates.first
    }
}

@MainActor
struct AutoRegistration {
    enum Outcome: Equatable {
        /// 登録した日数
        case registered(Int)
        /// 登録できる写真がなかった（その月の未登録の日に撮った写真がない）
        case noPhotos
        /// 写真へのアクセスが許可されていない
        case denied
    }

    let store: DiaryStore

    /// `month` の未登録の日（今日まで）に1枚ずつ登録する。`progress` には（終わった日数, 全体の日数）が届く。
    /// タスクがキャンセルされたら、そこまでで止める。
    func run(month: MonthGrid, progress: (Int, Int) -> Void) async -> Outcome {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { return .denied }

        let assets = fetchAssets(in: month)
        let today = DayKey.today()
        let photos = assets.values.compactMap { asset -> PhotoCandidate? in
            guard let createdAt = asset.creationDate else { return nil }
            return PhotoCandidate(id: asset.localIdentifier, day: DayKey(date: createdAt), createdAt: createdAt,
                                  isFavorite: asset.isFavorite, isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot))
        }
        let byDay = AutoPick.candidatesByDay(photos, skipping: Set(store.allKeys())).filter { $0.key <= today }
        let days = byDay.keys.sorted()
        guard !days.isEmpty else { return .noPhotos }

        var count = 0
        for (index, day) in days.enumerated() {
            if Task.isCancelled { break }
            progress(index, days.count)
            guard let images = await bestImages(from: byDay[day] ?? [], assets: assets) else { continue }
            // 変換している間に手で登録された日は上書きしない
            guard store.entry(for: day) == nil else { continue }
            if (try? store.save(images, for: day)) != nil { count += 1 }
        }
        progress(days.count, days.count)
        return count > 0 ? .registered(count) : .noPhotos
    }

    /// その月に撮った写真（ID ごと）
    private func fetchAssets(in month: MonthGrid) -> [String: PHAsset] {
        let start = DayKey(year: month.year, month: month.month, day: 1).date()
        let next = month.adding(months: 1)
        let end = DayKey(year: next.year, month: next.month, day: 1).date()
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                                        PHAssetMediaType.image.rawValue, start as NSDate, end as NSDate)
        var assets: [String: PHAsset] = [:]
        PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in assets[asset.localIdentifier] = asset }
        return assets
    }

    /// 候補から1枚選んで変換する。主役が写っているかは小さな画像で先に調べ、変換は選んだ1枚だけ行う
    private func bestImages(from candidates: [PhotoCandidate], assets: [String: PHAsset]) async -> EncodedEntryImages? {
        let checked = Array(candidates.prefix(AutoPick.maxChecksPerDay))
        var hasSubject: [Bool] = []
        for candidate in checked {
            guard let asset = assets[candidate.id], let thumbnail = await thumbnail(of: asset) else {
                hasSubject.append(false)
                continue
            }
            let found = await Task.detached(priority: .userInitiated) { CrayonFilter.hasSubject(in: thumbnail) }.value
            hasSubject.append(found)
            if found { break }
        }
        guard let chosen = AutoPick.pick(checked, hasSubject: hasSubject),
              let asset = assets[chosen.id],
              let data = await imageData(of: asset)
        else { return nil }
        return await Task.detached(priority: .userInitiated) { EntryImageProcessor.process(data: data) }.value
    }

    private func thumbnail(of asset: PHAsset) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 512, height: 512),
                                                  contentMode: .aspectFit, options: options) { image, _ in
                continuation.resume(returning: image?.cgImage)
            }
        }
    }

    private func imageData(of asset: PHAsset) async -> Data? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
