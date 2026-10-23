//
//  EntryImageProcessorTests.swift
//  CalenderPictureTests
//

import Testing
import UIKit
@testable import CalenderPicture

struct EntryImageProcessorTests {
    /// 中央に円がある width×height の画像。transparent なら背景透明
    func makeImage(width: Int, height: Int, transparent: Bool = false) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !transparent
        let size = CGSize(width: width, height: height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if !transparent {
                UIColor.systemTeal.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            UIColor.systemOrange.setFill()
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: size.width / 4, dy: size.height / 4))
        }.cgImage!
    }

    @Test func uprightAppliesOrientation() throws {
        let rotated = UIImage(cgImage: makeImage(width: 400, height: 200), scale: 1, orientation: .right)
        let upright = try #require(rotated.uprightCGImage(maxSize: 1000))
        #expect(upright.width == 200 && upright.height == 400)
    }

    @Test func uprightDownscalesToMaxSize() throws {
        let upright = try #require(UIImage(cgImage: makeImage(width: 3000, height: 1500)).uprightCGImage(maxSize: 2048))
        #expect(upright.width == 2048 && upright.height == 1024)
    }

    @Test func crayonDrawingIs1200LongSide() throws {
        let result = try #require(CrayonFilter.apply(to: makeImage(width: 1600, height: 1200)))
        #expect(max(result.drawing.width, result.drawing.height) == 1200)
    }

    @Test func encodesCharacterAsDownscaledPNGWithAlpha() throws {
        let crayon = CrayonResult(
            drawing: makeImage(width: 1200, height: 900),
            character: makeImage(width: 1200, height: 900, transparent: true)
        )
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 2048, height: 1536), crayon: crayon))
        let character = try #require(encoded.character.flatMap { UIImage(data: $0)?.cgImage })
        #expect(max(character.width, character.height) == 1024)
        let opaqueInfos: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
        #expect(!opaqueInfos.contains(character.alphaInfo))
        #expect(UIImage(data: encoded.drawing) != nil)
        #expect(UIImage(data: encoded.original) != nil)
    }

    @Test func noCharacterWhenSubjectMissing() throws {
        let crayon = CrayonResult(drawing: makeImage(width: 1200, height: 900), character: nil)
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 800, height: 600), crayon: crayon))
        #expect(encoded.character == nil)
    }

    @Test func processProducesDrawingAndOriginal() throws {
        let encoded = try #require(EntryImageProcessor.process(UIImage(cgImage: makeImage(width: 3000, height: 2000))))
        let original = try #require(UIImage(data: encoded.original)?.cgImage)
        #expect(max(original.width, original.height) == 2048)
        let drawing = try #require(UIImage(data: encoded.drawing)?.cgImage)
        #expect(max(drawing.width, drawing.height) == 1200)
    }
}
