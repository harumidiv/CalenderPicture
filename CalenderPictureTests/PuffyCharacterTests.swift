//
//  PuffyCharacterTests.swift
//  CalenderPictureTests
//

import RealityKit
import Testing
import UIKit
@testable import CalenderPicture

@MainActor
struct PuffyCharacterTests {
    /// 透明な背景の中央に丸い主役がいる画像
    func makeCharacter() -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 300, height: 400), format: format).image { context in
            UIColor.systemPink.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 30, y: 30, width: 240, height: 340))
        }.cgImage!
    }

    @Test func buildsExtrudedCharacterWithPhotoAndSideMaterials() throws {
        let character = try PuffyCharacter.make(from: makeCharacter())
        let body = try #require(character.findEntity(named: "body"))
        let model = try #require(body.children.first as? ModelEntity)
        #expect(model.model?.materials.count == 2)
        // 足元が原点、高さ 1
        let bounds = model.visualBounds(relativeTo: character)
        #expect(abs(bounds.min.y) < 0.05)
        #expect(abs(bounds.max.y - 1) < 0.05)
        #expect(bounds.extents.z > 0.05)  // 厚みがある
    }

    @Test func rejectsFullyTransparentImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let empty = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: format).image { _ in }.cgImage!
        #expect(throws: PuffyCharacter.BuildError.self) { try PuffyCharacter.make(from: empty) }
    }
}
