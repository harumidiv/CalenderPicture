//
//  DayKeyTests.swift
//  CalenderPictureTests
//

import Foundation
import Testing
@testable import CalenderPicture

struct DayKeyTests {
    @Test func stringIsZeroPadded() {
        #expect(DayKey(year: 2026, month: 3, day: 5).string == "2026-03-05")
    }

    @Test func parsesString() {
        #expect(DayKey(string: "2026-10-23") == DayKey(year: 2026, month: 10, day: 23))
        #expect(DayKey(string: "2026-13-01") == nil)
        #expect(DayKey(string: "2026-02-30") == nil)
        #expect(DayKey(string: "abc") == nil)
    }

    @Test func keyIgnoresTimeZoneOfSameComponents() {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        var hawaii = Calendar(identifier: .gregorian)
        hawaii.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        let key = DayKey(year: 2026, month: 10, day: 23)
        // どのタイムゾーンで 0 時を作っても、同じタイムゾーンで戻せば同じ日になる
        #expect(DayKey(date: key.date(in: tokyo), calendar: tokyo) == key)
        #expect(DayKey(date: key.date(in: hawaii), calendar: hawaii) == key)
    }

    @Test func ordersChronologically() {
        #expect(DayKey(year: 2026, month: 9, day: 30) < DayKey(year: 2026, month: 10, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}
