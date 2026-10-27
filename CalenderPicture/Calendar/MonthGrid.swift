//
//  MonthGrid.swift
//  CalenderPicture
//
//  月表示カレンダーのマスの並びを計算する。
//

import Foundation

nonisolated struct MonthGrid: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(containing key: DayKey) {
        self.init(year: key.year, month: key.month)
    }

    /// 先頭を週の始まり（`calendar.firstWeekday`）に合わせて nil で埋めた、その月の日付。末尾は埋めない。
    func cells(calendar: Calendar = .current) -> [DayKey?] {
        // 端末の暦が和暦などでも、月と曜日は西暦で数える（週の始まりとタイムゾーンは端末に従う）
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.firstWeekday = calendar.firstWeekday
        let calendar = gregorian
        let first = DayKey(year: year, month: month, day: 1).date(in: calendar)
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: first)!.count
        let days = (1...dayCount).map { DayKey(year: year, month: month, day: $0) }
        return Array(repeating: nil, count: leading) + days
    }

    func adding(months: Int) -> MonthGrid {
        let index = monthIndex + months
        return MonthGrid(year: Int((Double(index) / 12).rounded(.down)), month: ((index % 12) + 12) % 12 + 1)
    }

    /// `start` の月から `end` の月まで（両端を含む昇順）。`start` が `end` より後なら `end` の月だけ。
    static func months(from start: MonthGrid, through end: MonthGrid) -> [MonthGrid] {
        let count = max(end.monthIndex - start.monthIndex, 0)
        return (0...count).map { end.adding(months: $0 - count) }
    }

    static func < (lhs: MonthGrid, rhs: MonthGrid) -> Bool {
        lhs.monthIndex < rhs.monthIndex
    }

    /// 西暦0年1月からの通算の月
    private var monthIndex: Int {
        year * 12 + (month - 1)
    }

    /// 週の始まりから並べた曜日の短い表記。
    func weekdaySymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var title: String {
        "\(year)年\(month)月"
    }
}

extension MonthGrid: Identifiable {
    var id: String { "\(year)-\(month)" }
}
