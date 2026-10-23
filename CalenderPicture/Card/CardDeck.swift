//
//  CardDeck.swift
//  CalenderPicture
//
//  重なったカードの山。実物のカードのように、左へ払うと一番上のカードを横へ引き出して山の一番後ろへ回し、
//  右へ払うと一番後ろのカードを横へ引き出して一番上に乗せる。最後と最初がつながっていて無限にめくれる。
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
    /// カードを山へ戻す・乗せるアニメーション中は次の操作を受け付けない
    @State private var isSettling = false
    /// 山から横へ引き出しているカードとその位置。山へ戻す動きの出発点にする
    @State private var pulled: PulledCard?

    private struct PulledCard {
        let key: DayKey
        let x: Double
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // 縦に余裕がない画面でもはみ出さないよう、高さからも上限を決める
            let cardWidth = min(width * Self.cardWidthRatio, geometry.size.height * 0.8 * Self.cardAspectRatio)
            let cardHeight = cardWidth / Self.cardAspectRatio
            let index = items.firstIndex { $0.key == selection } ?? 0
            let pullOut = (width + cardWidth) / 2 + 12  // カードが山の横にちょうど出きる距離

            ZStack {
                ForEach(visibleCards(current: index), id: \.item.key) { card in
                    CardPage(
                        key: card.item.key,
                        drawingData: card.item.drawing,
                        originalData: card.item.original,
                        version: card.item.version,
                        isCurrent: card.depth == 0
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .modifier(DeckPlacement(
                        depth: card.depth,
                        count: items.count,
                        drag: drag,
                        pullOut: pullOut,
                        pulledX: pulled?.key == card.item.key ? pulled?.x : nil,
                        width: width
                    ))
                    // 上のカードほど手前（引き出し中の前の日のカードは、乗せるまで一番後ろ）
                    .zIndex(Double(items.count - card.depth))
                    .allowsHitTesting(card.depth == 0)
                    .accessibilityHidden(card.depth != 0)
                }
            }
            .frame(width: width, height: geometry.size.height)
            .contentShape(.rect)
            .gesture(dragGesture(width: width, pullOut: pullOut, index: index))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card-pager")
    }

    /// 描画するカード: 上から3枚と、一番後ろ（右へ払ったときに引き出す前の日）
    private func visibleCards(current index: Int) -> [(item: Item, depth: Int)] {
        guard !items.isEmpty else { return [] }
        let order = CardDeckGesture.deckOrder(current: index, count: items.count)
        var depths = Array(0..<min(DeckPlacement.visibleDepth, items.count))
        if items.count - 1 >= DeckPlacement.visibleDepth { depths.append(items.count - 1) }
        return depths.map { (items[order[$0]], $0) }
    }

    private func dragGesture(width: Double, pullOut: Double, index: Int) -> some Gesture {
        // 2枚以上あれば、どちらへも無限にめくれる
        let canMove = items.count > 1
        return DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isSettling else { return }
                let offset = CardDeckGesture.offset(for: value.translation.width, canGoNext: canMove, canGoPrevious: canMove)
                drag = min(max(offset, -pullOut), pullOut)
            }
            .onEnded { value in
                guard !isSettling else { return }
                let outcome = CardDeckGesture.outcome(
                    translation: value.translation.width,
                    predictedEnd: value.predictedEndTranslation.width,
                    width: width,
                    canGoNext: canMove,
                    canGoPrevious: canMove
                )
                settle(outcome, pullOut: pullOut, index: index)
            }
    }

    /// 指を離したあと: 山の後ろへ回す・一番上に乗せる・元に戻す
    private func settle(_ outcome: CardDeckGesture.Outcome, pullOut: Double, index: Int) {
        switch outcome {
        case .stay:
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { drag = 0 }
        case .next, .previous:
            let count = items.count
            let isNext = outcome == .next
            // 引き出すカード: 次へなら一番上、前へなら一番後ろ
            let movingKey = items[isNext ? index : CardDeckGesture.wrappedIndex(index, offset: -1, count: count)].key
            let newSelection = items[CardDeckGesture.wrappedIndex(index, offset: isNext ? 1 : -1, count: count)].key
            let side = isNext ? -pullOut : pullOut
            isSettling = true
            // 1. 山の横まで引き出しきる
            withAnimation(.spring(duration: 0.22, bounce: 0)) {
                drag = side
            } completion: {
                // 2. 引き出した位置のまま、重なり順だけを入れ替える（次へなら一番後ろへ、前へなら一番上へ）
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pulled = PulledCard(key: movingKey, x: side)
                    selection = newSelection
                    drag = 0
                }
                // 3. 山の位置へ差し込む
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    pulled = nil
                } completion: {
                    isSettling = false
                }
            }
        }
    }
}

/// 山の中の深さ（上から何枚目か）と指の移動量から、カードの位置・傾き・大きさを決める
private struct DeckPlacement: ViewModifier {
    /// 見える深さ（これより下のカードは、一番下の位置に重ねて隠す）
    static let visibleDepth = 3
    /// 画面幅ぶん横へ動いたときの傾き（度）
    static let tiltPerWidth = 12.0

    let depth: Int
    let count: Int
    let drag: Double
    let pullOut: Double
    /// 横へ引き出している最中なら、その位置
    let pulledX: Double?
    let width: Double

    private struct Pose {
        var x: Double, y: Double, rotation: Double, scale: Double, opacity: Double

        static func at(depth: Int) -> Pose {
            switch depth {
            case 0: Pose(x: 0, y: 0, rotation: 0, scale: 1, opacity: 1)
            case 1: Pose(x: -8, y: 8, rotation: -3.5, scale: 0.96, opacity: 1)
            case 2: Pose(x: 7, y: 14, rotation: 2.5, scale: 0.92, opacity: 1)
            default: Pose(x: 0, y: 18, rotation: 0, scale: 0.9, opacity: 0)
            }
        }

        func mixed(with other: Pose, _ t: Double) -> Pose {
            func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
            return Pose(x: mix(x, other.x), y: mix(y, other.y), rotation: mix(rotation, other.rotation),
                        scale: mix(scale, other.scale), opacity: mix(opacity, other.opacity))
        }
    }

    func body(content: Content) -> some View {
        let pose = currentPose()
        content
            .scaleEffect(pose.scale)
            .rotationEffect(.degrees(pose.rotation), anchor: .bottom)
            .offset(x: pose.x, y: pose.y)
            .opacity(pose.opacity)
    }

    private func currentPose() -> Pose {
        let tilt = { (x: Double) in x / width * Self.tiltPerWidth }
        // 引き出し中のカードは山の横にいる（前へなら一番上に乗る前、次へなら一番後ろへ差し込む前）
        if let pulledX {
            return Pose(x: pulledX, y: 0, rotation: tilt(pulledX), scale: 1, opacity: 1)
        }
        let base = Pose.at(depth: depth)
        let progress = min(abs(drag) / pullOut, 1)
        if drag < 0 {
            // 次へ: 一番上のカードが指について横へ出ていき、下のカードが1段ずつ持ち上がる
            if depth == 0 { return Pose(x: drag, y: 0, rotation: tilt(drag), scale: 1, opacity: 1) }
            return base.mixed(with: .at(depth: depth - 1), progress)
        }
        if drag > 0 {
            // 前へ: 一番後ろのカードが指について横へ出てきて、ほかのカードは1段ずつ沈む
            if depth == count - 1 {
                let x = drag
                return Pose(x: x, y: base.y * (1 - progress), rotation: tilt(x), scale: base.scale + (1 - base.scale) * progress, opacity: 1)
            }
            return base.mixed(with: .at(depth: depth + 1), progress)
        }
        return base
    }
}
