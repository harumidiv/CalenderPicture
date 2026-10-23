//
//  CardDeck.swift
//  CalenderPicture
//
//  重なったカードの山。左へ払うと一番上のカードが傾きながら飛んでいき、下から次の日のカードが出てくる。
//  右へ払うと前の日のカードが左から滑り込んできて、山の上に重なる。
//

import SwiftUI
import UIKit

struct CardDeck: View {
    /// 1日分のカードの中身（削除済みのモデルを非同期処理から触らないよう値で持つ）
    struct Item {
        let key: DayKey
        let drawing: Data
        let original: Data
        let version: Date
    }

    let items: [Item]
    @Binding var selection: DayKey

    /// カードの幅（画面幅に対する割合）と縦横比。DOOD のように画面の中央に小さめに置く
    static let cardWidthRatio = 0.58
    static let cardAspectRatio = 0.71

    /// 指の移動量（先がない方向は抑えた値）。左が負
    @State private var drag: Double = 0
    /// カードが飛んでいく・滑り込むアニメーション中は次の操作を受け付けない
    @State private var isSettling = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // 縦に余裕がない画面でもはみ出さないよう、高さからも上限を決める
            let cardWidth = min(width * Self.cardWidthRatio, geometry.size.height * 0.8 * Self.cardAspectRatio)
            let cardHeight = cardWidth / Self.cardAspectRatio
            let index = items.firstIndex { $0.key == selection } ?? 0
            let visible = visibleItems(around: index)

            ZStack {
                // 山の厚み: 後ろにのぞくカードの縁
                if items.count > 1 {
                    stackEdge(rotation: -3.5, x: -6, y: 6)
                        .frame(width: cardWidth, height: cardHeight)
                    stackEdge(rotation: 2.5, x: 5, y: 3)
                        .frame(width: cardWidth, height: cardHeight)
                }
                ForEach(visible, id: \.item.key) { entry in
                    CardPage(
                        key: entry.item.key,
                        drawingData: entry.item.drawing,
                        originalData: entry.item.original,
                        version: entry.item.version,
                        isCurrent: entry.role == .current
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .modifier(DeckPlacement(role: entry.role, drag: drag, width: width))
                    .allowsHitTesting(entry.role == .current)
                    .accessibilityHidden(entry.role != .current)
                }
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(.rect)
            .gesture(dragGesture(width: width, index: index))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-pager")
    }

    /// 重なり順（下から: 次の日、今の日、前の日）に並べた、描画するカード
    private func visibleItems(around index: Int) -> [(item: Item, role: DeckRole)] {
        var result: [(item: Item, role: DeckRole)] = []
        if items.indices.contains(index + 1) { result.append((items[index + 1], .next)) }
        if items.indices.contains(index) { result.append((items[index], .current)) }
        if items.indices.contains(index - 1) { result.append((items[index - 1], .previous)) }
        return result
    }

    private func stackEdge(rotation: Double, x: Double, y: Double) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.98, green: 0.975, blue: 0.965))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            .rotationEffect(.degrees(rotation))
            .offset(x: x, y: y)
            .scaleEffect(DeckPlacement.underScale)
            .accessibilityHidden(true)
    }

    private func dragGesture(width: Double, index: Int) -> some Gesture {
        let canGoNext = items.indices.contains(index + 1)
        let canGoPrevious = items.indices.contains(index - 1)
        return DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isSettling else { return }
                drag = CardDeckGesture.offset(for: value.translation.width, canGoNext: canGoNext, canGoPrevious: canGoPrevious)
            }
            .onEnded { value in
                guard !isSettling else { return }
                let outcome = CardDeckGesture.outcome(
                    translation: value.translation.width,
                    predictedEnd: value.predictedEndTranslation.width,
                    width: width,
                    canGoNext: canGoNext,
                    canGoPrevious: canGoPrevious
                )
                settle(outcome, width: width, index: index)
            }
    }

    /// 指を離したあと: 飛ばす・滑り込ませる・元に戻す
    private func settle(_ outcome: CardDeckGesture.Outcome, width: Double, index: Int) {
        let travel = width * DeckPlacement.travelRatio
        switch outcome {
        case .stay:
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { drag = 0 }
        case .next, .previous:
            let target = outcome == .next ? -travel : travel
            let newSelection = items[outcome == .next ? index + 1 : index - 1].key
            isSettling = true
            withAnimation(.spring(duration: 0.32, bounce: 0.15)) {
                drag = target
            } completion: {
                // 動き終わった見た目のまま役割を入れ替える（次の日が一番上に、または前の日が一番上に）
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selection = newSelection
                    drag = 0
                }
                isSettling = false
            }
        }
    }
}

/// 役割と指の移動量から、カードの位置・傾き・大きさを決める
private struct DeckPlacement: ViewModifier {
    /// 下に重なったカードの大きさ
    static let underScale = 0.94
    /// 飛んでいく・滑り込む距離（画面幅に対する割合）
    static let travelRatio = 1.25
    /// 画面幅ぶん動いたときの傾き（度）
    static let tiltPerWidth = 12.0

    let role: DeckRole
    let drag: Double
    let width: Double

    func body(content: Content) -> some View {
        let travel = width * Self.travelRatio
        let leftProgress = min(max(-drag, 0) / travel, 1)
        let rightProgress = min(max(drag, 0) / travel, 1)
        let (x, rotation, scale): (Double, Double, Double) = switch role {
        case .next:
            // 上のカードが左へ飛んでいくほど、下から持ち上がってくる
            (0, 0, Self.underScale + (1 - Self.underScale) * leftProgress)
        case .current:
            // 左へ払うと指について飛んでいく。右へ払うと前の日が上に重なるので、少し沈む
            (min(drag, 0), min(drag, 0) / width * Self.tiltPerWidth, 1 - (1 - Self.underScale) * rightProgress)
        case .previous:
            // 画面の左外で待っていて、右へ払うと指について滑り込んでくる
            (-travel + max(drag, 0), (-travel + max(drag, 0)) / width * Self.tiltPerWidth, 1)
        }
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .offset(x: x)
    }
}

/// 山の中でのカードの役割（重なり順の下から）
private enum DeckRole {
    case next, current, previous
}
