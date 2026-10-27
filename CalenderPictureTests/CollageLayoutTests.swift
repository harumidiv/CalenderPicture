//
//  CollageLayoutTests.swift
//  CalenderPictureTests
//

import CoreGraphics
import Testing
@testable import CalenderPicture

struct CollageLayoutTests {
    let bounds = CGRect(x: 12, y: 14, width: 336, height: 422)
    let title = CGRect(x: 0, y: 0, width: 200, height: 150)
    var reserved: [CGRect] { [title] }

    @Test func placesEveryStickerOnThePaper() {
        for count in [1, 5, 12, 31] {
            let placements = CollageLayout.place(count: count, in: bounds, avoiding: reserved, seed: 42)
            #expect(placements.count == count)
            for placement in placements {
                // はみ出してよいのは一辺の bleed ぶんまで
                let inset = placement.size * (0.5 - CollageLayout.bleed) - 0.5
                #expect(bounds.insetBy(dx: inset, dy: inset).contains(placement.center))
                #expect(abs(placement.rotation) <= CollageLayout.maxRotation)
            }
        }
    }

    @Test func fillsMostOfThePaper() {
        // 見出しをよけるぶん、枚数が少ない月ほど隙間が残る（丸で数えているので、見た目はもう少し埋まる）
        for (count, minimum) in [(4, 0.65), (12, 0.8), (24, 0.82)] {
            let placements = CollageLayout.place(count: count, in: bounds, avoiding: reserved, seed: 5)
            #expect(CollageLayout.filledRatio(of: placements, in: bounds, avoiding: reserved) > minimum, "\(count)枚で隙間が多い")
        }
    }

    @Test func sameSeedGivesSameLayout() {
        let a = CollageLayout.place(count: 8, in: bounds, avoiding: reserved, seed: 7)
        #expect(a == CollageLayout.place(count: 8, in: bounds, avoiding: reserved, seed: 7))
        #expect(a != CollageLayout.place(count: 8, in: bounds, avoiding: reserved, seed: 8))
    }

    @Test func stickersMostlyStayOffTheTitle() {
        for count in [4, 12] {
            for placement in CollageLayout.place(count: count, in: bounds, avoiding: reserved, seed: 3) {
                let rect = CGRect(x: placement.center.x - placement.size / 2, y: placement.center.y - placement.size / 2,
                                  width: placement.size, height: placement.size)
                let overlap = rect.intersection(title)
                let ratio = overlap.isNull ? 0 : overlap.width * overlap.height / (rect.width * rect.height)
                #expect(ratio < 0.2)
            }
        }
    }

    @Test func noStickersForEmptyMonth() {
        #expect(CollageLayout.place(count: 0, in: bounds, avoiding: reserved, seed: 1).isEmpty)
    }

    @Test func extraLayerFillsRemainingGaps() {
        let first = CollageLayout.place(count: 4, in: bounds, avoiding: reserved, seed: 9)
        let extra = CollageLayout.place(count: 4, in: bounds, avoiding: reserved, seed: 10, over: first)
        let before = CollageLayout.filledRatio(of: first, in: bounds, avoiding: reserved)
        let after = CollageLayout.filledRatio(of: first + extra, in: bounds, avoiding: reserved)
        #expect(after > before + 0.1, "おかわりで隙間が埋まっていない")
        // 大きさは1段目と同じ範囲
        #expect(extra.map(\.size).max()! > first.map(\.size).min()! * 0.8)
    }
}
