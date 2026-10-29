//
//  AutoPickTests.swift
//  CalenderPictureTests
//

import Foundation
import Testing
@testable import CalenderPicture

struct AutoPickTests {
    let day1 = DayKey(year: 2026, month: 9, day: 1)
    let day2 = DayKey(year: 2026, month: 9, day: 2)

    func photo(_ id: String, _ day: DayKey, hour: Int, favorite: Bool = false, screenshot: Bool = false) -> PhotoCandidate {
        PhotoCandidate(id: id, day: day, createdAt: day.date().addingTimeInterval(Double(hour) * 3600),
                       isFavorite: favorite, isScreenshot: screenshot)
    }

    @Test func favoritesFirstThenLatest() {
        let photos = [photo("a", day1, hour: 9), photo("b", day1, hour: 18), photo("c", day1, hour: 12, favorite: true)]
        let byDay = AutoPick.candidatesByDay(photos, skipping: [])
        #expect(byDay[day1]?.map(\.id) == ["c", "b", "a"])
    }

    @Test func skipsScreenshotsAndRegisteredDays() {
        let photos = [photo("a", day1, hour: 9), photo("s", day2, hour: 10, screenshot: true), photo("b", day2, hour: 8)]
        let byDay = AutoPick.candidatesByDay(photos, skipping: [day1])
        #expect(byDay[day1] == nil)
        #expect(byDay[day2]?.map(\.id) == ["b"])
    }

    @Test func picksFirstPhotoWithSubject() {
        let candidates = [photo("a", day1, hour: 18), photo("b", day1, hour: 12), photo("c", day1, hour: 9)]
        #expect(AutoPick.pick(candidates, hasSubject: [false, true, true])?.id == "b")
    }

    @Test func fallsBackToFirstWhenNoSubject() {
        let candidates = [photo("a", day1, hour: 18), photo("b", day1, hour: 12)]
        #expect(AutoPick.pick(candidates, hasSubject: [false, false])?.id == "a")
        // 調べ終わる前に止まった（結果が足りない）ときも先頭
        #expect(AutoPick.pick(candidates, hasSubject: [])?.id == "a")
        #expect(AutoPick.pick([], hasSubject: []) == nil)
    }
}
