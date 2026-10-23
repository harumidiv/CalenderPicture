//
//  CardNavigation.swift
//  CalenderPicture
//

nonisolated enum CardNavigation {
    /// 表示中の日を削除したあとに表示する日。次の日を優先し、なければ前の日、どちらもなければ nil（カードを閉じる）。
    /// `keys` は昇順。
    static func neighborAfterDeleting(_ key: DayKey, in keys: [DayKey]) -> DayKey? {
        keys.first { $0 > key } ?? keys.last { $0 < key }
    }
}
