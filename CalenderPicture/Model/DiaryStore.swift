//
//  DiaryStore.swift
//  CalenderPicture
//
//  写真日記の読み書き。
//

import Foundation
import SwiftData

@MainActor
struct DiaryStore {
    let context: ModelContext

    func entry(for key: DayKey) -> DiaryEntry? {
        let dayKey = key.string
        var descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// その日の写真を保存する。すでにあれば上書きする。
    func save(_ images: EncodedEntryImages, for key: DayKey) throws {
        if let existing = entry(for: key) {
            existing.drawingData = images.drawing
            existing.originalData = images.original
            existing.characterData = images.character
            existing.cutoutData = images.cutout
            existing.updatedAt = .now
        } else {
            context.insert(DiaryEntry(key: key, images: images))
        }
        try context.save()
    }

    func delete(_ key: DayKey) throws {
        guard let existing = entry(for: key) else { return }
        context.delete(existing)
        try context.save()
    }

    /// 登録済みの日（昇順）。
    func allKeys() -> [DayKey] {
        let descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.dayKey)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.key)
    }
}
