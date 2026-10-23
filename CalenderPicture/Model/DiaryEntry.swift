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
        DayKey(string: dayKey)!
    }
}

/// 保存用にエンコード済みの画像。
nonisolated struct EncodedEntryImages: Sendable {
    let drawing: Data
    let original: Data
    let character: Data?
}
