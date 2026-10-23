//
//  DiaryEntry.swift
//  CalenderPicture
//
//  1日1枚の写真日記。クレヨン画・元写真・（切り抜けたときだけ）透明なクレヨンのキャラクターを持つ。
//

import Foundation
import SwiftData

@Model
final class DiaryEntry {
    /// `DayKey.string`（`yyyy-MM-dd`）。1日1件の一意キー。
    @Attribute(.unique) var dayKey: String
    /// 紙の背景つきクレヨン画（JPEG）
    @Attribute(.externalStorage) var drawingData: Data
    /// 元写真（JPEG）
    @Attribute(.externalStorage) var originalData: Data
    /// 背景が透明なクレヨンのキャラクター（PNG）。3D 表示用。被写体を切り抜けなかったときは nil
    @Attribute(.externalStorage) var characterData: Data?
    var updatedAt: Date

    init(key: DayKey, images: EncodedEntryImages) {
        dayKey = key.string
        drawingData = images.drawing
        originalData = images.original
        characterData = images.character
        updatedAt = .now
    }

    var key: DayKey {
        // 保存時に DayKey.string から作った値なので必ず解釈できる。万一壊れていても落とさず、数字だけ読む
        if let key = DayKey(string: dayKey) { return key }
        let parts = dayKey.split(separator: "-").map { Int($0) ?? 0 }
        return DayKey(year: parts.first ?? 0, month: parts.dropFirst().first ?? 0, day: parts.dropFirst(2).first ?? 0)
    }
}

/// 保存用にエンコード済みの画像。
nonisolated struct EncodedEntryImages: Sendable {
    let drawing: Data
    let original: Data
    let character: Data?
}
