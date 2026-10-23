//
//  WanderCast.swift
//  CalenderPicture
//
//  3D 空間で動き回るキャラクターを選ぶ。被写体を切り抜けた（キャラクター画像がある）日だけが対象。
//

import Foundation

nonisolated enum WanderCast {
    /// 登録内容のうち 3D 表示に使うもの
    struct Source {
        let key: DayKey
        let character: Data?
        let cutout: Data?
    }

    /// 動き回る1体。`cutout` は切り抜き写真（古い登録では nil）
    struct Member {
        let key: DayKey
        let character: Data
        let cutout: Data?
    }

    /// `month` に登録された日のうち、キャラクター画像がある日（日付の昇順）。
    static func characters(in month: MonthGrid, from entries: [Source]) -> [Member] {
        entries
            .compactMap { entry in entry.character.map { Member(key: entry.key, character: $0, cutout: entry.cutout) } }
            .filter { $0.key.year == month.year && $0.key.month == month.month }
            .sorted { $0.key < $1.key }
    }
}
