//
//  DoodStyle.swift
//  CalenderPicture
//
//  DOOD のように、明るいグレーの地に白い面を影で浮かせる見た目の部品。
//

import SwiftUI
import UIKit

enum DoodStyle {
    /// 画面の地の色
    static let background = Color(.systemGroupedBackground)
    /// 地の上に浮かせる面の色（ライトモードでは白）
    static let surface = Color(.secondarySystemGroupedBackground)
    /// 浮かせる面の影
    static let shadowColor = Color.black.opacity(0.08)
}

/// 下に並べるカプセル型のボタン。主アクションは黒地、それ以外は白地
struct PillButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded).weight(.semibold))
            .foregroundStyle(isProminent ? Color(.systemBackground) : Color.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 15)
            .background(isProminent ? Color.primary : DoodStyle.surface, in: .capsule)
            .shadow(color: DoodStyle.shadowColor, radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var prominentPill: PillButtonStyle { PillButtonStyle(isProminent: true) }
}

/// アイコンだけの丸いボタンの見た目（「…」「×」など）
struct CircleIcon: View {
    let systemName: String
    var size: CGFloat = 40
    var isProminent = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(isProminent ? Color(.systemBackground) : Color.primary)
            .frame(width: size, height: size)
            .background(isProminent ? Color.primary : DoodStyle.surface, in: .circle)
            .shadow(color: DoodStyle.shadowColor, radius: 8, y: 3)
            .contentShape(.circle)
    }
}
