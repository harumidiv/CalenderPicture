//
//  DayCell.swift
//  CalenderPicture
//
//  カレンダーの1マス。登録済みならクレヨン画のサムネイルを、シールのように上からペタッと貼る。
//

import SwiftUI
import UIKit

struct DayCell: View {
    static let aspectRatio: CGFloat = 0.78

    let day: Int
    /// クレヨン画のデータ。削除済みのモデルを非同期処理から触らないよう、モデルではなく値で受け取る
    let drawingData: Data?
    /// サムネイルを作り直すきっかけ（更新日時）
    let version: Date?
    let isToday: Bool
    /// シールを貼るまでの待ち時間（秒）。月の中で日付の早い順に少しずつずらす
    var stickerDelay: Double = 0
    /// 貼ったあとのシールの傾き（度）
    var stickerTilt: Double = 0

    @State private var thumbnail: UIImage?
    /// シールが貼られたか（false のあいだは上に浮いていて見えない）
    @State private var isStuck = false
    /// 一度貼ったあと（登録し直したとき）は順番を待たずにすぐ貼る
    @State private var hasStuckOnce = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.secondarySystemBackground))
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    sticker(thumbnail)
                }
            }
            .overlay(alignment: .topLeading) {
                Text("\(day)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(minWidth: 18, minHeight: 18)
                    .background {
                        if isToday {
                            Circle().fill(.tint)
                        } else if thumbnail != nil {
                            Circle().fill(.background.opacity(0.85))
                        }
                    }
                    .padding(3)
            }
            .contentShape(.rect)
            .task(id: version) {
                let image = await Self.makeThumbnail(from: drawingData)
                isStuck = false
                thumbnail = image
                guard image != nil else { return }
                // 少し弾むばねで、上から落ちてきて着いた瞬間にペタッとつぶれて戻る
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(hasStuckOnce ? 0.05 : stickerDelay)) {
                    isStuck = true
                }
                hasStuckOnce = true
            }
    }

    private func sticker(_ image: UIImage) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.white)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(.rect(cornerRadius: 8))
            // 浮いているあいだは影が大きく薄く、貼ると小さく濃くなる
            .shadow(color: .black.opacity(isStuck ? 0.14 : 0.08), radius: isStuck ? 1.5 : 10, y: isStuck ? 1 : 12)
            .scaleEffect(isStuck ? 1 : 1.45)
            .rotationEffect(.degrees(isStuck ? stickerTilt : stickerTilt * 4 - 6))
            .offset(y: isStuck ? 0 : -36)
            .opacity(isStuck ? 1 : 0)
    }

    private static func makeThumbnail(from data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .utility) {
            await UIImage(data: data)?.byPreparingThumbnail(ofSize: CGSize(width: 160, height: 160))
        }.value
    }
}
