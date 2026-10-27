//
//  CrayonBrightnessTests.swift
//  CalenderPictureTests
//

import CoreGraphics
import Foundation
import Testing
@testable import CalenderPicture

struct CrayonBrightnessTests {
    @Test func darkSubjectIsLiftedToTarget() {
        let power = CrayonFilter.brighteningPower(forLuma: 0.4)
        #expect(power < 1)
        #expect(abs(pow(0.4, power) - CrayonFilter.targetLuma) < 0.001)
    }

    @Test func brightSubjectIsNotDarkened() {
        #expect(CrayonFilter.brighteningPower(forLuma: CrayonFilter.targetLuma) == 1)
        #expect(CrayonFilter.brighteningPower(forLuma: 0.8) == 1)
    }

    @Test func veryDarkSubjectIsLiftedOnlyUpToLimit() {
        #expect(CrayonFilter.brighteningPower(forLuma: 0.05) == CrayonFilter.minimumPower)
        // 真っ黒（測れない）なら変えない
        #expect(CrayonFilter.brighteningPower(forLuma: 0) == 1)
    }
}
