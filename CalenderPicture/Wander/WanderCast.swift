//
//  WanderCast.swift
//  CalenderPicture
//
//  3D 空間で動き回るキャラクターを選ぶ。被写体を切り抜けた（キャラクター画像がある）日だけが対象。
//

import Foundation

nonisolated enum WanderCast {
    /// `month` に登録された日のうち、キャラクター画像がある日（日付の昇順）。
    static func characters(in month: MonthGrid, from entries: [(key: DayKey, character: Data?)]) -> [(key: DayKey, character: Data)] {
        entries
            .compactMap { entry in entry.character.map { (key: entry.key, character: $0) } }
            .filter { $0.key.year == month.year && $0.key.month == month.month }
            .sorted { $0.key < $1.key }
    }
}
