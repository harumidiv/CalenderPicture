//
//  DayKey.swift
//  CalenderPicture
//
//  カレンダー上の「日」を年・月・日で表す。時刻やタイムゾーンに依存しないので、
//  旅行などでタイムゾーンが変わっても登録した日がずれない。
//

import Foundation

nonisolated struct DayKey: Hashable, Comparable, Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    /// `"2026-10-23"` 形式を解釈する。実在しない日付は nil。
    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let key = DayKey(year: parts[0], month: parts[1], day: parts[2])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard DayKey(date: key.date(in: calendar), calendar: calendar) == key else { return nil }
        self = key
    }

    /// ゼロ埋めの `yyyy-MM-dd`。
    var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// その日の 0 時。
    func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(date: Date(), calendar: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
