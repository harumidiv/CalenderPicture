//
//  FaceSofteningTests.swift
//  CalenderPictureTests
//

import CoreImage
import Testing
import UIKit
@testable import CalenderPicture

struct FaceSofteningTests {
    static let skin = UIColor(red: 0.85, green: 0.68, blue: 0.58, alpha: 1)
    static let skinLuma: CGFloat = 0.299 * 0.85 + 0.587 * 0.68 + 0.114 * 0.58
    /// 顔の枠（Core Image 座標）
    static let face = CGRect(x: 150, y: 150, width: 300, height: 300)

    /// 肌色の顔に、暗い目・眉・口がある 600×600 の画像
    func makeFace() -> CIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 600, height: 600)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            Self.skin.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.12, alpha: 1).setFill()
            let c = context.cgContext
            c.fillEllipse(in: CGRect(x: 205, y: 255, width: 50, height: 30))  // 目
            c.fillEllipse(in: CGRect(x: 345, y: 255, width: 50, height: 30))
            c.fill(CGRect(x: 200, y: 230, width: 60, height: 10))              // 眉
            c.fill(CGRect(x: 340, y: 230, width: 60, height: 10))
            c.fillEllipse(in: CGRect(x: 240, y: 360, width: 120, height: 30))  // 口
        }
        return CIImage(cgImage: image.cgImage!)
    }

    /// 範囲内の平均の明るさ
    func luma(of image: CIImage, in box: CGRect) -> CGFloat {
        let average = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: box)])
        var pixel = [Float](repeating: 0, count: 4)
        CrayonFilter.context.render(average, toBitmap: &pixel, rowBytes: 16, bounds: average.extent, format: .RGBAf, colorSpace: nil)
        return CGFloat(0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])
    }

    /// 顔のパーツの暗さが広がって、顔全体が肌より暗くならない
    @Test func softenedFaceKeepsSkinBrightness() {
        let softened = CrayonFilter.softenFaces([Self.face], in: makeFace())
        let center = Self.face.insetBy(dx: 75, dy: 75)
        #expect(luma(of: softened, in: center) > Self.skinLuma - 0.03)
    }

    /// 目の位置も肌の明るさに近くなる（暗い穴として残らない）
    @Test func softenedFaceRemovesDarkEyes() {
        let softened = CrayonFilter.softenFaces([Self.face], in: makeFace())
        // 左目の中心（UIKit の y = 270 は Core Image では 600 - 270）
        let eye = CGRect(x: 225, y: 325, width: 10, height: 10)
        #expect(luma(of: softened, in: eye) > Self.skinLuma - 0.06)
    }
}
