//
//  WanderStageTests.swift
//  CalenderPictureTests
//

import Foundation
import Testing
import UIKit
@testable import CalenderPicture

@MainActor
struct WanderStageTests {
    func png(_ color: UIColor) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 260), format: format).image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 20, y: 20, width: 160, height: 220))
        }.pngData()!
    }

    @Test func switchesBetweenCrayonAndPhoto() async {
        let stage = WanderStage()
        await stage.show([
            WanderCast.Member(key: DayKey(year: 2026, month: 10, day: 3), character: png(.systemPink), cutout: png(.systemTeal)),
            WanderCast.Member(key: DayKey(year: 2026, month: 10, day: 9), character: png(.systemOrange), cutout: nil),
        ])
        #expect(stage.displayedStyles == [.crayon, .crayon])

        await stage.setStyle(.photo)
        // 切り抜き写真がない日はクレヨンのまま
        #expect(stage.displayedStyles == [.photo, .crayon])

        await stage.setStyle(.crayon)
        #expect(stage.displayedStyles == [.crayon, .crayon])
    }

    @Test func charactersAddedAfterSwitchUseCurrentStyle() async {
        let stage = WanderStage()
        await stage.setStyle(.photo)
        await stage.show([
            WanderCast.Member(key: DayKey(year: 2026, month: 10, day: 3), character: png(.systemPink), cutout: png(.systemTeal)),
        ])
        #expect(stage.displayedStyles == [.photo])
    }
}
