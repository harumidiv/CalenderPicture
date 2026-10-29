//
//  DayCell.swift
//  CalenderPicture
//
//  カレンダーの1マス。DOOD のようにマスの枠は描かず、未登録の日は数字だけ、
//  登録済みの日は数字の代わりにクレヨン画をシールのように上からペタッと貼る。
//

import SwiftUI
import UIKit

struct DayCell: View {
    static let aspectRatio: CGFloat = 0.9

    let day: Int
    /// 貼る画像のデータ。削除済みのモデルを非同期処理から触らないよう、モデルではなく値で受け取る
    let imageData: Data?
    /// 画像が背景の透明なキャラクターか（false なら紙の背景つきのクレヨン画なので角を丸めて切る）
    var isCutout = false
    /// サムネイルを作り直すきっかけ（更新日時）
    let version: Date?
    let isToday: Bool
    /// シールを貼るまでの待ち時間（秒）。月の中でランダムな順に少しずつずらす
    var stickerDelay: Double = 0
    /// 貼ったあとのシールの傾き（度）
    var stickerTilt: Double = 0

    @State private var thumbnail: UIImage?
    /// シールが貼られたか（false のあいだは上に浮いていて見えない）
    @State private var isStuck = false
    /// 一度貼ったあと（登録し直したとき）は順番を待たずにすぐ貼る
    @State private var hasStuckOnce = false

    var body: some View {
        Color.clear
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    sticker(thumbnail)
                } else {
                    number
                }
            }
            .contentShape(.rect)
            .task(id: version) {
                let image = await Self.makeThumbnail(from: imageData)
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

    private var number: some View {
        Text("\(day)")
            .font(.system(.callout, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isToday ? Color.white : Color.primary)
            .frame(width: 30, height: 30)
            .background {
                if isToday { Circle().fill(.tint) }
            }
    }

    @ViewBuilder
    private func sticker(_ image: UIImage) -> some View {
        Group {
            if isCutout {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(2)
            } else {
                // マスの大きさに収めて、はみ出た部分を切る
                Color.white
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(.rect(cornerRadius: 6))
                    .padding(3)
            }
        }
        // 浮いているあいだは影が大きく薄く、貼ると小さく濃くなる
        .shadow(color: .black.opacity(isStuck ? 0.16 : 0.08), radius: isStuck ? 1.5 : 10, y: isStuck ? 1 : 12)
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
