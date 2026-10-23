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
        let entries: [(key: DayKey, character: Data?)] = [
            (DayKey(year: 2026, month: 10, day: 9), Data([2])),
            (DayKey(year: 2026, month: 10, day: 3), Data([1])),
            (DayKey(year: 2026, month: 10, day: 5), nil),           // 切り抜けなかった日は動かない
            (DayKey(year: 2026, month: 9, day: 30), Data([3])),     // 別の月
            (DayKey(year: 2025, month: 10, day: 1), Data([4])),     // 別の年の同じ月
        ]
        let cast = WanderCast.characters(in: october, from: entries)
        #expect(cast.map(\.key.day) == [3, 9])
        #expect(cast.map(\.character) == [Data([1]), Data([2])])
    }

    @Test func emptyWhenNoCharacters() {
        let entries: [(key: DayKey, character: Data?)] = [(DayKey(year: 2026, month: 10, day: 5), nil)]
        #expect(WanderCast.characters(in: october, from: entries).isEmpty)
    }
}
