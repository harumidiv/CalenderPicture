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

    @Test func preparesShapeOffMainThread() async throws {
        let image = makeCharacter()
        // 重い計算（形・テクスチャの準備）はメインスレッド外で行い、RealityKit への登録だけをメインで行う
        let prepared = try await Task.detached { try PuffyCharacter.prepare(from: image) }.value
        let model = try PuffyCharacter.makeModel(from: prepared)
        #expect(model.model?.materials.count == 2)
        let bounds = model.visualBounds(relativeTo: nil)
        #expect(abs(bounds.min.y) < 0.05)
        #expect(abs(bounds.max.y - 1) < 0.05)
    }

    /// テクスチャの (x, y)（左上原点）の RGB
    func rgb(_ image: CGImage, _ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return (pixel[0], pixel[1], pixel[2])
    }

    @Test func textureBleedsSubjectColorJustOutsideEdge() throws {
        // 透明な背景に赤い円（半径 100）。縁のすぐ外は赤がにじみ、遠い角は塗られない（黒）
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200), format: format).image { context in
            UIColor(red: 1, green: 0, blue: 0, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 200, height: 200))
        }.cgImage!
        let texture = try PuffyCharacter.prepare(from: image).texture
        #expect(rgb(texture, 100, 100).r > 200)  // 円の中
        let nearEdge = rgb(texture, 28, 28)       // 円の外側、縁から約3px
        #expect(nearEdge.r > 200 && nearEdge.g < 60 && nearEdge.b < 60)
        let corner = rgb(texture, 0, 0)           // 縁から約40px離れた角
        #expect(corner.r < 30)
    }

    @Test func rejectsFullyTransparentImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let empty = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50), format: format).image { _ in }.cgImage!
        #expect(throws: PuffyCharacter.BuildError.self) { try PuffyCharacter.make(from: empty) }
    }
}
