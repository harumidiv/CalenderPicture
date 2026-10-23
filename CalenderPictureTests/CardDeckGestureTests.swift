//
//  CardDeckGestureTests.swift
//  CalenderPictureTests
//

import Testing
@testable import CalenderPicture

struct CardDeckGestureTests {
    let width = 400.0

    func outcome(_ translation: Double, predicted: Double? = nil, next: Bool = true, previous: Bool = true) -> CardDeckGesture.Outcome {
        CardDeckGesture.outcome(translation: translation, predictedEnd: predicted ?? translation, width: width,
                                canGoNext: next, canGoPrevious: previous)
    }

    @Test func swipeLeftGoesToNextDay() {
        #expect(outcome(-150) == .next)            // 画面幅の3割を超えた
        #expect(outcome(-60, predicted: -300) == .next)  // 短くても勢いよく払った
    }

    @Test func swipeRightGoesToPreviousDay() {
        #expect(outcome(150) == .previous)
        #expect(outcome(60, predicted: 300) == .previous)
    }

    @Test func shortSlowDragStays() {
        #expect(outcome(-80) == .stay)
        #expect(outcome(80) == .stay)
    }

    @Test func cannotGoBeyondEnds() {
        #expect(outcome(-200, next: false) == .stay)      // 最後の日より先はない
        #expect(outcome(200, previous: false) == .stay)   // 最初の日より前はない
    }

    @Test func dragBeyondEndsIsResisted() {
        // 先がない方向へは少ししか動かない
        #expect(CardDeckGesture.offset(for: -200, canGoNext: false, canGoPrevious: true) == -50)
        #expect(CardDeckGesture.offset(for: 200, canGoNext: true, canGoPrevious: false) == 50)
        #expect(CardDeckGesture.offset(for: -200, canGoNext: true, canGoPrevious: true) == -200)
    }
}
