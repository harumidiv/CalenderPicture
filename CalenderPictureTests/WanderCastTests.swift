//
//  WanderCastTests.swift
//  CalenderPictureTests
//

import Foundation
import Testing
@testable import CalenderPicture

struct WanderCastTests {
    let october = MonthGrid(year: 2026, month: 10)

    @Test func picksOnlyEntriesWithCharacterInMonth() {
        let entries: [WanderCast.Source] = [
            .init(key: DayKey(year: 2026, month: 10, day: 9), character: Data([2]), cutout: nil),  // 切り抜き写真がない古い登録
            .init(key: DayKey(year: 2026, month: 10, day: 3), character: Data([1]), cutout: Data([11])),
            .init(key: DayKey(year: 2026, month: 10, day: 5), character: nil, cutout: nil),         // 切り抜けなかった日は動かない
            .init(key: DayKey(year: 2026, month: 9, day: 30), character: Data([3]), cutout: nil),   // 別の月
            .init(key: DayKey(year: 2025, month: 10, day: 1), character: Data([4]), cutout: nil),   // 別の年の同じ月
        ]
        let cast = WanderCast.characters(in: october, from: entries)
        #expect(cast.map(\.key.day) == [3, 9])
        #expect(cast.map(\.character) == [Data([1]), Data([2])])
        #expect(cast.map(\.cutout) == [Data([11]), nil])
    }

    @Test func emptyWhenNoCharacters() {
        let entries: [WanderCast.Source] = [.init(key: DayKey(year: 2026, month: 10, day: 5), character: nil, cutout: nil)]
        #expect(WanderCast.characters(in: october, from: entries).isEmpty)
    }
}
