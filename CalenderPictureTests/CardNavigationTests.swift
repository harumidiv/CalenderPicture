//
//  CardNavigationTests.swift
//  CalenderPictureTests
//

import Testing
@testable import CalenderPicture

struct CardNavigationTests {
    let a = DayKey(year: 2026, month: 10, day: 1)
    let b = DayKey(year: 2026, month: 10, day: 5)
    let c = DayKey(year: 2026, month: 10, day: 9)

    @Test func neighborAfterDeletion() {
        // 次の日を優先し、なければ前の日、どちらもなければ nil（カードを閉じる）
        #expect(CardNavigation.neighborAfterDeleting(b, in: [a, b, c]) == c)
        #expect(CardNavigation.neighborAfterDeleting(c, in: [a, b, c]) == b)
        #expect(CardNavigation.neighborAfterDeleting(a, in: [a]) == nil)
    }

    @Test func neighborWhenKeyMissing() {
        #expect(CardNavigation.neighborAfterDeleting(b, in: [a, c]) == c)
        #expect(CardNavigation.neighborAfterDeleting(b, in: []) == nil)
    }
}
