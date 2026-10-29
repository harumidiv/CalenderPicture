//
//  CalendarView.swift
//  CalenderPicture
//
//  シートで開くカレンダー。DOOD のように月を縦に積み、登録済みの日はクレヨン画のシールを貼る。
//  一番古い登録の月（少なくとも先月）から今月までを並べ、開いたときは今月を見せる。
//  一番上の「前の月を表示」で、1か月ずつさかのぼれる。
//  月ごとの「自動で登録」で、写真ライブラリからその月の未登録の日に1枚ずつ登録できる。
//  月ごとの共有ボタンで、その月のらくがきをカレンダーの形に並べた1枚の画像を共有できる。
//

import SwiftData
import SwiftUI

struct CalendarView: View {
    var onSelectEntry: (DayKey) -> Void
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.dayKey) private var entries: [DiaryEntry]
    /// 自動で登録している月と進み具合
    @State private var autoProgress: AutoProgress?
    @State private var autoTask: Task<Void, Never>?
    @State private var toast: String?
    @State private var photoRequest: PhotoRequest?
    @State private var wanderMonth: MonthGrid?
    @State private var sharingMonth: MonthShare?
    /// 「前の月を表示」でさかのぼった月数
    @State private var earlierMonths = 0
    /// シールを貼る順番の乱数の種。カレンダーを開くたびに変わる
    @State private var stickerSeed = UInt64.random(in: .min ... .max)

    var body: some View {
        let thisMonth = MonthGrid(containing: .today())
        let first = entries.first.map { MonthGrid(containing: $0.key) } ?? thisMonth
        let earliest = min(first, thisMonth.adding(months: -1)).adding(months: -earlierMonths)
        let months = MonthGrid.months(from: earliest, through: thisMonth)
        let entriesByKey = Dictionary(entries.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })

        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 36) {
                        Button("前の月を表示", systemImage: "chevron.up") {
                            earlierMonths += 1
                            // 足した月が見出しから見えるよう、その月を上に合わせる
                            let added = earliest.adding(months: -1)
                            Task { withAnimation { proxy.scrollTo(added.id, anchor: .top) } }
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("calendar-show-earlier")

                        ForEach(months) { month in
                            MonthSection(
                                month: month,
                                entriesByKey: entriesByKey,
                                stickerSeed: stickerSeed,
                                onSelect: { key in
                                    if entriesByKey[key.string] != nil { onSelectEntry(key) } else { photoRequest = PhotoRequest(day: key) }
                                },
                                onOpenWander: { wanderMonth = month },
                                onAutoRegister: { autoRegister(month) },
                                onShare: { sharingMonth = share(of: month, entriesByKey: entriesByKey) },
                                isAutoRegistering: autoProgress != nil
                            )
                            .id(month.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                // 新しい月が下に来るので、開いたときは一番下（今月）を見せる
                .defaultScrollAnchor(.bottom, for: .initialOffset)
            }
        }
        .background(DoodStyle.surface.ignoresSafeArea())
        .overlay(alignment: .bottom) { statusBar }
        .presentationDragIndicator(.visible)
        .onDisappear { autoTask?.cancel() }
        .photoRegistration($photoRequest)
        .sheet(item: $sharingMonth) { share in
            MonthShareSheet(share: share) { sharingMonth = nil }
        }
        .fullScreenCover(item: $wanderMonth) { month in
            WanderView(month: month) { wanderMonth = nil }
        }
    }

    private struct AutoProgress {
        let month: MonthGrid
        var done = 0
        var total = 0
    }

    /// 自動で登録している間の進み具合と、終わったときの知らせ
    @ViewBuilder
    private var statusBar: some View {
        Group {
            if let autoProgress {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(autoProgress.total == 0 ? "写真を探しています…" : "\(autoProgress.month.title)を登録中 \(autoProgress.done)/\(autoProgress.total)")
                        .monospacedDigit()
                    Button("止める") { autoTask?.cancel() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("auto-register-stop")
                }
                .accessibilityIdentifier("auto-register-progress")
            } else if let toast {
                Text(toast)
                    .accessibilityIdentifier("auto-register-result")
            }
        }
        .font(.system(.subheadline, design: .rounded))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: DoodStyle.shadowColor, radius: 10, y: 4)
        .padding(.bottom, 16)
        .opacity(autoProgress == nil && toast == nil ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: autoProgress == nil && toast == nil)
    }

    /// その月に登録した日の絵（切り抜けた日はキャラクター、そうでない日は紙ごとのクレヨン画）
    private func share(of month: MonthGrid, entriesByKey: [String: DiaryEntry]) -> MonthShare {
        let stickers = month.cells().compactMap { $0 }.reduce(into: [DayKey: MonthSticker]()) { result, key in
            guard let entry = entriesByKey[key.string] else { return }
            result[key] = MonthSticker(data: entry.characterData ?? entry.drawingData, isCutout: entry.characterData != nil)
        }
        return MonthShare(month: month, stickers: stickers)
    }

    private func autoRegister(_ month: MonthGrid) {
        guard autoProgress == nil else { return }
        autoProgress = AutoProgress(month: month)
        toast = nil
        autoTask = Task {
            let outcome = await AutoRegistration(store: DiaryStore(context: modelContext)).run(month: month) { done, total in
                autoProgress?.done = done
                autoProgress?.total = total
            }
            autoProgress = nil
            let message = switch outcome {
            case .registered(let count): "\(month.title)に\(count)日分を登録しました"
            case .noPhotos: "\(month.title)の未登録の日に撮った写真がありませんでした"
            case .denied: "写真へのアクセスを「設定」で許可してください"
            }
            toast = message
            try? await Task.sleep(for: .seconds(3))
            if toast == message { toast = nil }
        }
    }

    private var header: some View {
        ZStack {
            Text("カレンダー")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            HStack {
                Spacer()
                Button(action: onClose) {
                    CircleIcon(systemName: "xmark", size: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
                .accessibilityIdentifier("calendar-close")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

/// 1か月ぶん: 月の見出し、曜日、日付のマス
private struct MonthSection: View {
    let month: MonthGrid
    let entriesByKey: [String: DiaryEntry]
    let stickerSeed: UInt64
    var onSelect: (DayKey) -> Void
    var onOpenWander: () -> Void
    var onAutoRegister: () -> Void
    var onShare: () -> Void
    var isAutoRegistering: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cells = month.cells()
        let today = DayKey.today()
        // この月で登録済みの日を、ランダムな順にシールを貼る
        let stickerOrder = StickerMotion.order(of: cells.compactMap { $0 }.filter { entriesByKey[$0.string] != nil }, seed: stickerSeed)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(month.title)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("自動で登録", systemImage: "wand.and.stars", action: onAutoRegister)
                    .labelStyle(.titleAndIcon)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DoodStyle.background, in: .capsule)
                    .disabled(isAutoRegistering)
                    .accessibilityLabel("\(month.title)の未登録の日を写真から自動で登録")
                    .accessibilityIdentifier("auto-register-\(month.id)")
                let hasEntries = cells.contains { $0.map { entriesByKey[$0.string] != nil } ?? false }
                Button("\(month.title)のらくがきを1枚にして共有", systemImage: "square.and.arrow.up", action: onShare)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .opacity(hasEntries ? 1 : 0.35)
                    .disabled(!hasEntries)
                    .accessibilityIdentifier("month-share-\(month.id)")
                Button("\(month.title)のキャラクターを動かす", systemImage: "figure.walk", action: onOpenWander)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("open-wander-\(month.id)")
            }
            .padding(.horizontal, 4)
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                ForEach(Array(month.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, key in
                    if let key {
                        let entry = entriesByKey[key.string]
                        // 被写体を切り抜けた日は背景のないキャラクターを、そうでない日は紙ごとのクレヨン画を貼る
                        DayCell(
                            day: key.day,
                            imageData: entry.map { $0.characterData ?? $0.drawingData },
                            isCutout: entry?.characterData != nil,
                            version: entry?.updatedAt,
                            isToday: key == today,
                            stickerDelay: StickerMotion.delay(order: stickerOrder[key] ?? 0),
                            stickerTilt: StickerMotion.tilt(for: key)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(key.month)月\(key.day)日")
                        .accessibilityValue(entry == nil ? "未登録" : "登録済み")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("day-\(key.string)")
                        .onTapGesture { onSelect(key) }
                    } else {
                        Color.clear.aspectRatio(DayCell.aspectRatio, contentMode: .fit)
                    }
                }
            }
        }
    }
}
