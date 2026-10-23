//
//  EntryImageProcessorTests.swift
//  CalenderPictureTests
//

import ImageIO
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
            character: makeImage(width: 1200, height: 900, transparent: true),
            photoCutout: nil
        )
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 2048, height: 1536), crayon: crayon))
        let character = try #require(encoded.character.flatMap { UIImage(data: $0)?.cgImage })
        #expect(max(character.width, character.height) == 1024)
        let opaqueInfos: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
        #expect(!opaqueInfos.contains(character.alphaInfo))
        #expect(UIImage(data: encoded.drawing) != nil)
        #expect(UIImage(data: encoded.original) != nil)
    }

    @Test func encodesPhotoCutoutAsDownscaledPNG() throws {
        let crayon = CrayonResult(
            drawing: makeImage(width: 1200, height: 900),
            character: makeImage(width: 1200, height: 900, transparent: true),
            photoCutout: makeImage(width: 1100, height: 1400, transparent: true)
        )
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 800, height: 600), crayon: crayon))
        let cutout = try #require(encoded.cutout.flatMap { UIImage(data: $0)?.cgImage })
        #expect(max(cutout.width, cutout.height) == 1024)
        let opaqueInfos: [CGImageAlphaInfo] = [.none, .noneSkipLast, .noneSkipFirst]
        #expect(!opaqueInfos.contains(cutout.alphaInfo))
    }

    @Test func noCharacterWhenSubjectMissing() throws {
        let crayon = CrayonResult(drawing: makeImage(width: 1200, height: 900), character: nil, photoCutout: nil)
        let encoded = try #require(EntryImageProcessor.encode(original: makeImage(width: 800, height: 600), crayon: crayon))
        #expect(encoded.character == nil)
        #expect(encoded.cutout == nil)
    }

    /// EXIF の向き（6 = 右に 90 度回して表示）つき JPEG
    func makeRotatedJPEG(width: Int, height: Int) throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, makeImage(width: width, height: height),
                                   [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func downsampleAppliesOrientationAndMaxSize() throws {
        let image = try #require(ImageDownsampler.downsample(try makeRotatedJPEG(width: 4000, height: 2000), maxPixelSize: 2048))
        #expect(image.width == 1024 && image.height == 2048)
    }

    @Test func downsampleKeepsSmallImageSize() throws {
        let image = try #require(ImageDownsampler.downsample(try makeRotatedJPEG(width: 400, height: 200), maxPixelSize: 2048))
        #expect(image.width == 200 && image.height == 400)
    }

    @Test func cardImagesAreDownsampledForDisplay() throws {
        let original = try #require(UIImage(cgImage: makeImage(width: 2048, height: 1536)).jpegData(compressionQuality: 0.8))
        let drawing = try #require(UIImage(cgImage: makeImage(width: 1200, height: 900)).jpegData(compressionQuality: 0.8))
        let images = try #require(CardImageLoader.load(drawing: drawing, original: original))
        #expect(max(images.original.size.width, images.original.size.height) == CardImageLoader.maxPixelSize)
        #expect(max(images.drawing.size.width, images.drawing.size.height) == 1200)
    }

    @Test func processDataProducesDrawingAndOriginal() throws {
        let encoded = try #require(EntryImageProcessor.process(data: try makeRotatedJPEG(width: 3000, height: 2000)))
        let original = try #require(UIImage(data: encoded.original)?.cgImage)
        #expect(original.width == 1365 && original.height == 2048)
        let drawing = try #require(UIImage(data: encoded.drawing)?.cgImage)
        #expect(max(drawing.width, drawing.height) == 1200)
    }

    @Test func processProducesDrawingAndOriginal() throws {
        let encoded = try #require(EntryImageProcessor.process(UIImage(cgImage: makeImage(width: 3000, height: 2000))))
        let original = try #require(UIImage(data: encoded.original)?.cgImage)
        #expect(max(original.width, original.height) == 2048)
        let drawing = try #require(UIImage(data: encoded.drawing)?.cgImage)
        #expect(max(drawing.width, drawing.height) == 1200)
    }
}
