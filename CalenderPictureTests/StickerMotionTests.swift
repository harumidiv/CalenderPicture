//
//  StickerMotionTests.swift
//  CalenderPictureTests
//

import Testing
@testable import CalenderPicture

struct StickerMotionTests {
    @Test func stickersArePlacedOneByOneInOrder() {
        // 日付の早い順に、少しずつずらして貼る
        let delays = (0..<5).map { StickerMotion.delay(order: $0) }
        #expect(delays == delays.sorted())
        #expect(Set(delays).count == 5)
        #expect(delays[0] > 0)  // 画面が出てから貼り始める
        #expect(delays[1] - delays[0] < 0.2)  // 待たせすぎない
    }

    @Test func tiltIsSmallAndStablePerDay() {
        for day in 1...31 {
            let key = DayKey(year: 2026, month: 10, day: day)
            let tilt = StickerMotion.tilt(for: key)
            #expect(abs(tilt) <= 3)
            #expect(StickerMotion.tilt(for: key) == tilt)  // 毎回同じ向き
        }
        // すべて同じ向きにはならない
        let tilts = Set((1...31).map { StickerMotion.tilt(for: DayKey(year: 2026, month: 10, day: $0)) })
        #expect(tilts.count > 3)
    }
}
