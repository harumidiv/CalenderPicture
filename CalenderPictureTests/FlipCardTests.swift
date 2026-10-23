//
//  FlipCardTests.swift
//  CalenderPictureTests
//

import Testing
@testable import CalenderPicture

struct FlipCardTests {
    @Test func onlyFrontIsVisibleBeforeHalfTurn() {
        for angle in [0.0, 45, 89] {
            #expect(FlipCard.opacity(ofBack: false, angle: angle) == 1)
            #expect(FlipCard.opacity(ofBack: true, angle: angle) == 0)
        }
    }

    @Test func onlyBackIsVisibleAfterHalfTurn() {
        // 回転の途中で両面が重なって透けたり、反転した面が見えたりしない
        for angle in [91.0, 135, 180] {
            #expect(FlipCard.opacity(ofBack: false, angle: angle) == 0)
            #expect(FlipCard.opacity(ofBack: true, angle: angle) == 1)
        }
    }
}
