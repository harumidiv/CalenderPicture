//
//  CardPage.swift
//  CalenderPicture
//

import SwiftUI
import UIKit

/// 1日分のカード。画像のデコードは非同期で行う。
/// 裏返しの状態はカードごとに持つ。写真が未登録の日は、タップで写真を追加する白いカードを出す。
struct CardPage: View {
    let key: DayKey
    let photo: CardDeck.Photo?
    let isCurrent: Bool
    var onAddPhoto: () -> Void = {}

    @State private var isFlipped = false

    @State private var images: (drawing: UIImage, original: UIImage)?

    private var footnote: String {
        key.date().formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }

    var body: some View {
        Group {
            if photo == nil {
                EmptyDayCard(footnote: footnote, isAccessible: isCurrent, onTap: onAddPhoto)
            } else if let images {
                // 山の下に重なっているカードは読み上げない
                FlipCard(front: Image(uiImage: images.drawing), back: Image(uiImage: images.original),
                         isFlipped: $isFlipped, isAccessible: isCurrent, footnote: footnote)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // ほかの日へ移ったら表に戻す（隣の日のカードは山の中に残り続けるので onDisappear では戻らない）
        .onChange(of: isCurrent) { _, current in
            if !current { isFlipped = false }
        }
        .task(id: photo?.version) {
            guard let photo else {
                images = nil
                return
            }
            let drawingData = photo.drawing, originalData = photo.original
            images = await Task.detached(priority: .userInitiated) {
                CardImageLoader.load(drawing: drawingData, original: originalData)
            }.value
        }
    }
}

/// 写真が未登録の日のカード。紙の色の面に「＋」と日付を出し、タップで写真を選ぶ
struct EmptyDayCard: View {
    let footnote: String
    var isAccessible = true
    var onTap: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.98, green: 0.975, blue: 0.965))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .padding(12)
            }
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .semibold))
                    Text("写真を追加")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(Color(white: 0.45))
            }
            .overlay(alignment: .bottom) {
                Text(footnote)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.bottom, 24)
            }
            .shadow(color: .black.opacity(0.14), radius: 10, y: 5)
            .contentShape(.rect)
            .onTapGesture(perform: onTap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(footnote) 写真を追加")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(isAccessible ? "card-empty" : "card-under")
            .accessibilityHidden(!isAccessible)
    }
}
