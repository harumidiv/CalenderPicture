//
//  CardDeckGesture.swift
//  CalenderPicture
//
//  重なったカードの山をスワイプしたときに、次の日・前の日へ移るか、元に戻るかを決める。
//  左へ払うと次の日（一番上のカードを引き出して山の一番後ろへ回す）、
//  右へ払うと前の日（一番後ろのカードを引き出して一番上に乗せる）。山は最後と最初がつながっていて無限にめくれる。
//

import Foundation

nonisolated enum CardDeckGesture {
    enum Outcome: Equatable {
        case next
        case previous
        case stay
    }

    /// 画面幅に対して、これより長く引っぱったら移る
    static let distanceThreshold = 0.3
    /// 指を離したあとの勢い（予測される到達点）が、画面幅に対してこれより遠ければ移る
    static let velocityThreshold = 0.6
    /// 先がない方向へ引っぱったときの動きの割合
    static let resistance = 0.25

    static func outcome(translation: Double, predictedEnd: Double, width: Double,
                        canGoNext: Bool, canGoPrevious: Bool) -> Outcome {
        let passed = abs(translation) > width * distanceThreshold || abs(predictedEnd) > width * velocityThreshold
        guard passed else { return .stay }
        if translation < 0 || (translation == 0 && predictedEnd < 0) {
            return canGoNext ? .next : .stay
        }
        return canGoPrevious ? .previous : .stay
    }

    /// 最後と最初がつながった山での、`index` から `offset` 枚ずらした位置。
    static func wrappedIndex(_ index: Int, offset: Int, count: Int) -> Int {
        ((index + offset) % count + count) % count
    }

    /// 山の上から順の並び（今の日、次の日、…、一番後ろが前の日）。
    static func deckOrder(current: Int, count: Int) -> [Int] {
        (0..<count).map { wrappedIndex(current, offset: $0, count: count) }
    }

    /// 指の移動量に対するカードの移動量。先がない方向へは少ししか動かない。
    static func offset(for translation: Double, canGoNext: Bool, canGoPrevious: Bool) -> Double {
        let allowed = translation < 0 ? canGoNext : canGoPrevious
        return allowed ? translation : translation * resistance
    }
}
