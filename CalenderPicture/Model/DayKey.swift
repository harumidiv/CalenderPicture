//
//  DayKey.swift
//  CalenderPicture
//
//  カレンダー上の「日」を年・月・日（西暦）で表す。時刻やタイムゾーンに依存しないので、
//  旅行などでタイムゾーンが変わっても登録した日がずれない。
//  端末の暦が和暦・仏暦でも年がずれないよう、計算は常に西暦（グレゴリオ暦）で行う。
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

    /// `calendar` はタイムゾーンだけを使う（暦の種類は無視して西暦で数える）。
    init(date: Date, calendar: Calendar = .current) {
        let components = Self.gregorian(timeZone: calendar.timeZone).dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    /// `"2026-10-23"` 形式を解釈する。実在しない日付は nil。
    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let key = DayKey(year: parts[0], month: parts[1], day: parts[2])
        let calendar = Self.gregorian(timeZone: TimeZone(identifier: "UTC")!)
        guard DayKey(date: key.date(in: calendar), calendar: calendar) == key else { return nil }
        self = key
    }

    /// ゼロ埋めの `yyyy-MM-dd`。
    var string: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// その日の 0 時（`calendar` のタイムゾーンで）。
    func date(in calendar: Calendar = .current) -> Date {
        Self.gregorian(timeZone: calendar.timeZone).date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func gregorian(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// `days` 日あとの日（負なら前の日）。
    func adding(days: Int) -> DayKey {
        let utc = Self.gregorian(timeZone: TimeZone(identifier: "UTC")!)
        return DayKey(date: utc.date(byAdding: .day, value: days, to: date(in: utc))!, calendar: utc)
    }

    /// `start` から `end` まで（両端を含む昇順）。`start` が後なら空。
    static func days(from start: DayKey, through end: DayKey) -> [DayKey] {
        guard start <= end else { return [] }
        return Array(sequence(first: start) { $0 < end ? $0.adding(days: 1) : nil })
    }

    static func today(calendar: Calendar = .current) -> DayKey {
        DayKey(date: Date(), calendar: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension DayKey: Identifiable {
    var id: String { string }
}
