//
//  MonthGridTests.swift
//  CalenderPictureTests
//

import Foundation
import Testing
@testable import CalenderPicture

struct MonthGridTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test func octoberStartsOnThursday() {
        let sunday = MonthGrid(year: 2026, month: 10).cells(calendar: calendar(firstWeekday: 1))
        #expect(sunday.prefix(4).allSatisfy { $0 == nil })
        #expect(sunday[4] == DayKey(year: 2026, month: 10, day: 1))
        #expect(sunday.compactMap { $0 }.count == 31)
        let monday = MonthGrid(year: 2026, month: 10).cells(calendar: calendar(firstWeekday: 2))
        #expect(monday[3] == DayKey(year: 2026, month: 10, day: 1))
    }

    @Test func japaneseCalendarUsesGregorianMonth() {
        var japanese = Calendar(identifier: .japanese)
        japanese.firstWeekday = 1
        let cells = MonthGrid(year: 2028, month: 2).cells(calendar: japanese)
        #expect(cells.compactMap { $0 }.count == 29)
        #expect(cells.compactMap { $0 }.last == DayKey(year: 2028, month: 2, day: 29))
        #expect(cells.prefix(2).allSatisfy { $0 == nil })  // 2028/2/1 は火曜
    }

    @Test func augustNeedsSixRows() {
        let cells = MonthGrid(year: 2026, month: 8).cells(calendar: calendar(firstWeekday: 1))
        #expect(cells.count == 37)  // 先頭6マス + 31日 → 6行
        #expect(cells.last == DayKey(year: 2026, month: 8, day: 31))
    }

    @Test func leapFebruary() {
        let cells = MonthGrid(year: 2028, month: 2).cells(calendar: calendar(firstWeekday: 1))
        #expect(cells.compactMap { $0 }.count == 29)
    }

    @Test func addingMonthsCrossesYear() {
        #expect(MonthGrid(year: 2026, month: 12).adding(months: 1) == MonthGrid(year: 2027, month: 1))
        #expect(MonthGrid(year: 2026, month: 1).adding(months: -1) == MonthGrid(year: 2025, month: 12))
    }

    @Test func weekdaySymbolsFollowFirstWeekday() {
        var japanese = calendar(firstWeekday: 2)
        japanese.locale = Locale(identifier: "ja_JP")
        #expect(MonthGrid(year: 2026, month: 10).weekdaySymbols(calendar: japanese) == ["月", "火", "水", "木", "金", "土", "日"])
    }

    @Test func titleShowsYearAndMonth() {
        #expect(MonthGrid(year: 2026, month: 10).title == "2026年10月")
    }

    @Test func containingKeyUsesItsMonth() {
        #expect(MonthGrid(containing: DayKey(year: 2026, month: 10, day: 23)) == MonthGrid(year: 2026, month: 10))
    }
}
