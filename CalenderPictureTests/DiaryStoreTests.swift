//
//  DiaryStoreTests.swift
//  CalenderPictureTests
//

import Foundation
import SwiftData
import Testing
@testable import CalenderPicture

@MainActor
struct DiaryStoreTests {
    let container: ModelContainer
    let store: DiaryStore
    let images = EncodedEntryImages(drawing: Data([1]), original: Data([2]), character: nil)
    let day = DayKey(year: 2026, month: 10, day: 23)

    init() throws {
        container = try ModelContainer(
            for: DiaryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = DiaryStore(context: container.mainContext)
    }

    @Test func saveOverwritesSameDay() throws {
        try store.save(images, for: day)
        try store.save(EncodedEntryImages(drawing: Data([9]), original: Data([8]), character: Data([7])), for: day)
        #expect(store.allKeys() == [day])
        #expect(store.entry(for: day)?.drawingData == Data([9]))
        #expect(store.entry(for: day)?.originalData == Data([8]))
        #expect(store.entry(for: day)?.characterData == Data([7]))
    }

    @Test func allKeysAreSorted() throws {
        try store.save(images, for: DayKey(year: 2026, month: 10, day: 25))
        try store.save(images, for: DayKey(year: 2026, month: 9, day: 1))
        try store.save(images, for: day)
        #expect(store.allKeys().map(\.string) == ["2026-09-01", "2026-10-23", "2026-10-25"])
    }

    @Test func deleteRemovesEntry() throws {
        try store.save(images, for: day)
        try store.delete(day)
        #expect(store.entry(for: day) == nil)
        #expect(store.allKeys().isEmpty)
    }

    @Test func entryExposesItsKey() throws {
        try store.save(images, for: day)
        #expect(store.entry(for: day)?.key == day)
    }
}
