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

    @Test func deckWrapsAround() {
        // 最後の日の次は最初の日、最初の日の前は最後の日（実物のカードの山のように無限にめくれる）
        #expect(CardDeckGesture.wrappedIndex(4, offset: 1, count: 5) == 0)
        #expect(CardDeckGesture.wrappedIndex(0, offset: -1, count: 5) == 4)
        #expect(CardDeckGesture.wrappedIndex(2, offset: 1, count: 5) == 3)
    }

    @Test func deckOrderStartsFromCurrent() {
        // 山の上から順に: 今の日、次の日、その次…と並び、最後に前の日（一番後ろ）
        #expect(CardDeckGesture.deckOrder(current: 3, count: 5) == [3, 4, 0, 1, 2])
        #expect(CardDeckGesture.deckOrder(current: 0, count: 1) == [0])
    }

    @Test func dragBeyondEndsIsResisted() {
        // 先がない方向へは少ししか動かない
        #expect(CardDeckGesture.offset(for: -200, canGoNext: false, canGoPrevious: true) == -50)
        #expect(CardDeckGesture.offset(for: 200, canGoNext: true, canGoPrevious: false) == 50)
        #expect(CardDeckGesture.offset(for: -200, canGoNext: true, canGoPrevious: true) == -200)
    }
}
