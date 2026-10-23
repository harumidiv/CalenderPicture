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

    @Test func usesGregorianYearEvenWithJapaneseCalendar() {
        // 端末の暦が和暦・仏暦でも、キーは西暦で作る（和暦の 2028/2/29 は「令和10年」になり、西暦検証で nil になっていた）
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let leapDay = gregorian.date(from: DateComponents(year: 2028, month: 2, day: 29))!
        for identifier in [Calendar.Identifier.japanese, .buddhist] {
            var calendar = Calendar(identifier: identifier)
            calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
            let key = DayKey(date: leapDay, calendar: calendar)
            #expect(key == DayKey(year: 2028, month: 2, day: 29))
            #expect(DayKey(string: key.string) == key)
            #expect(DayKey(date: key.date(in: calendar), calendar: calendar) == key)
        }
    }

    @Test func ordersChronologically() {
        #expect(DayKey(year: 2026, month: 9, day: 30) < DayKey(year: 2026, month: 10, day: 1))
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }
}
