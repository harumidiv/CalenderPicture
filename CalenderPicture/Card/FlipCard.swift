//
//  FlipCard.swift
//  CalenderPicture
//
//  タップで Y 軸回りにくるっと裏返るカード。表はクレヨン画、裏は元写真。
//

import SwiftUI

struct FlipCard: View {
    let front: Image
    let back: Image
    @Binding var isFlipped: Bool

    var body: some View {
        let angle = isFlipped ? 180.0 : 0.0
        ZStack {
            face(front, fill: false)
                .opacity(isFlipped ? 0 : 1)
            // 裏面はあらかじめ 180 度回しておき、カードが裏返ったときに左右反転して見えないようにする
            face(back, fill: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .animation(.spring(duration: 0.6, bounce: 0.25), value: isFlipped)
        .contentShape(.rect)
        .onTapGesture { isFlipped.toggle() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFlipped ? "元の写真" : "クレヨン画")
        .accessibilityValue(isFlipped ? "back" : "front")
        .accessibilityHint("タップで裏返す")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("card")
    }

    private func face(_ image: Image, fill: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(red: 0.98, green: 0.975, blue: 0.965))
            .overlay {
                if fill {
                    image.resizable().scaledToFill()
                } else {
                    image.resizable().scaledToFit()
                }
            }
            .clipShape(.rect(cornerRadius: 24))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}
