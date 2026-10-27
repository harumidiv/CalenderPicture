//
//  CollageLayout.swift
//  CalenderPicture
//
//  ひと月の画像に貼るらくがきの置き場所を決める。ばらばらに見えるよう乱数で置くが、
//  候補をいくつか試して「まだ絵が乗っていない紙を一番多く埋める」場所を選ぶので、紙いっぱいに敷き詰まる。
//  見出しなどの場所には、できるだけかぶせない。
//

import CoreGraphics

nonisolated enum CollageLayout {
    struct Placement: Equatable {
        var center: CGPoint
        /// 正方形の一辺（絵はこの中に収める）
        var size: CGFloat
        /// 傾き（度）
        var rotation: Double
    }

    /// 1枚あたりに試す置き場所の候補数。多いほど隙間なく埋まる
    static let candidates = 80
    /// 絵の面積の合計を、紙の面積の何倍にするか（1 より大きくして、少し重ねて隙間をなくす）
    static let coverage: CGFloat = 1.7
    /// 紙の外にはみ出してよい割合（一辺に対して）。端まで絵があるように見せる
    static let bleed: CGFloat = 0.15
    /// 傾きの最大（度）
    static let maxRotation = 14.0
    /// 埋まり具合を数えるマス目の細かさ（紙の長辺あたり）
    private static let resolution = 40

    /// `count` 枚を `bounds` に敷き詰めて置く。`reserved`（見出しなど）にはできるだけかぶせない
    static func place(count: Int, in bounds: CGRect, avoiding reserved: [CGRect], seed: UInt64) -> [Placement] {
        guard count > 0, bounds.width > 0, bounds.height > 0 else { return [] }
        var random = SplitMix64(state: seed)
        // 枚数が少ないほど大きく
        let base = min(max((bounds.width * bounds.height * coverage / CGFloat(count)).squareRoot(), bounds.width * 0.26),
                       bounds.width * 0.85)
        var paper = CoverageGrid(bounds: bounds, resolution: resolution, reserved: reserved)
        // 大きい絵から置くと、小さい絵が隙間を埋めてきれいに詰まる
        let sizes = (0..<count).map { _ in base * .random(in: 0.85...1.15, using: &random) }.sorted(by: >)
        var placed: [Placement] = []
        for size in sizes {
            let inset = size * (0.5 - bleed)
            let area = bounds.insetBy(dx: inset, dy: inset)
            var best: (placement: Placement, score: CGFloat)?
            for _ in 0..<candidates {
                let center = CGPoint(x: .random(in: area.minX...max(area.minX, area.maxX), using: &random),
                                     y: .random(in: area.minY...max(area.minY, area.maxY), using: &random))
                let placement = Placement(center: center, size: size,
                                          rotation: .random(in: -maxRotation...maxRotation, using: &random))
                let score = score(placement, on: paper, avoiding: reserved)
                if best == nil || score > best!.score { best = (placement, score) }
            }
            placed.append(best!.placement)
            paper.cover(center: best!.placement.center, radius: size * coveredRadius)
        }
        // 重なり順は乱数で混ぜる（大きい絵がいつも下にならないように）
        return placed.shuffled(using: &random)
    }

    /// 絵が紙を埋めるとみなす半径（一辺に対して）。キャラクターは丸っこいので、四角より少し小さい円で数える
    private static let coveredRadius: CGFloat = 0.42

    /// まだ埋まっていない紙をどれだけ埋めるか。見出しなどにかぶると大きく減らす
    private static func score(_ placement: Placement, on paper: CoverageGrid, avoiding reserved: [CGRect]) -> CGFloat {
        var score = paper.uncoveredArea(center: placement.center, radius: placement.size * coveredRadius)
        let rect = CGRect(x: placement.center.x - placement.size / 2, y: placement.center.y - placement.size / 2,
                          width: placement.size, height: placement.size)
        for area in reserved {
            let overlap = rect.intersection(area)
            if !overlap.isNull { score -= overlap.width * overlap.height * 3 }
        }
        return score
    }

    /// 紙をマス目に分けて、絵が乗ったマスを覚えておく
    private struct CoverageGrid {
        let bounds: CGRect
        let columns: Int, rows: Int
        let cell: CGFloat
        var covered: [Bool]

        init(bounds: CGRect, resolution: Int, reserved: [CGRect]) {
            self.bounds = bounds
            cell = max(bounds.width, bounds.height) / CGFloat(resolution)
            columns = Int((bounds.width / cell).rounded(.up))
            rows = Int((bounds.height / cell).rounded(.up))
            covered = Array(repeating: false, count: columns * rows)
            // 見出しの場所は、はじめから埋まっているものとして扱う（埋めに行かない）
            for row in 0..<rows {
                for column in 0..<columns where reserved.contains(where: { $0.contains(point(column, row)) }) {
                    covered[row * columns + column] = true
                }
            }
        }

        func point(_ column: Int, _ row: Int) -> CGPoint {
            CGPoint(x: bounds.minX + (CGFloat(column) + 0.5) * cell, y: bounds.minY + (CGFloat(row) + 0.5) * cell)
        }

        private func cells(center: CGPoint, radius: CGFloat) -> [Int] {
            let minColumn = max(0, Int((center.x - radius - bounds.minX) / cell))
            let maxColumn = min(columns - 1, Int((center.x + radius - bounds.minX) / cell))
            let minRow = max(0, Int((center.y - radius - bounds.minY) / cell))
            let maxRow = min(rows - 1, Int((center.y + radius - bounds.minY) / cell))
            guard minColumn <= maxColumn, minRow <= maxRow else { return [] }
            var result: [Int] = []
            for row in minRow...maxRow {
                for column in minColumn...maxColumn {
                    let p = point(column, row)
                    if hypot(p.x - center.x, p.y - center.y) <= radius { result.append(row * columns + column) }
                }
            }
            return result
        }

        func uncoveredArea(center: CGPoint, radius: CGFloat) -> CGFloat {
            CGFloat(cells(center: center, radius: radius).filter { !covered[$0] }.count) * cell * cell
        }

        mutating func cover(center: CGPoint, radius: CGFloat) {
            for index in cells(center: center, radius: radius) { covered[index] = true }
        }

        /// 埋まっている割合（見出しも含む）
        var filledRatio: CGFloat { CGFloat(covered.filter { $0 }.count) / CGFloat(covered.count) }
    }

    /// テスト用: 置いた結果で紙のどれだけが埋まるか（見出しの場所も埋まっているものとして数える）
    static func filledRatio(of placements: [Placement], in bounds: CGRect, avoiding reserved: [CGRect]) -> CGFloat {
        var paper = CoverageGrid(bounds: bounds, resolution: resolution, reserved: reserved)
        for placement in placements { paper.cover(center: placement.center, radius: placement.size * coveredRadius) }
        return paper.filledRatio
    }
}
