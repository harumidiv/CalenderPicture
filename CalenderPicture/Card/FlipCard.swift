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
                .modifier(FlipFace(angle: angle, isBack: false))
            face(back, fill: true)
                .modifier(FlipFace(angle: angle, isBack: true))
        }
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

    /// 回転角度（0〜180）での各面の不透明度。90 度を境に表と裏をきっぱり切り替え、
    /// 回転の途中で両面が重なったり、反転した面が透けたりしないようにする。
    nonisolated static func opacity(ofBack isBack: Bool, angle: Double) -> Double {
        (angle < 90) != isBack ? 1 : 0
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

/// アニメーション中の角度を受け取り、面を回転させて表示・非表示を切り替える。
/// 裏面は 180 度ずらして回すので、裏返し終わったときに写真が左右反転しない。
private struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(isBack ? angle - 180 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .opacity(FlipCard.opacity(ofBack: isBack, angle: angle))
    }
}
