//
//  StainedGlassFilter.swift
//  CalenderPicture
//
//  写真の主役をステンドグラスのような絵に変換する。色の下ごしらえは Core Image、
//  ガラス片と鉛の枠を描くところは Metal（StainedGlass.metal）で行う。
//

import CoreImage

nonisolated enum StainedGlassFilter {
    /// StainedGlass.metal の StainedGlassParams と同じ並び
    private struct Params {
        var cellSize: Float
        var leadWidth: Float
        var outlineWidth: Float
    }

    /// 主役の長辺を、ガラス片が何枚くらい並ぶ大きさに分けるか
    private static let cellsAcrossSubject: CGFloat = 15

    /// Metal が使えないなど、変換できなかったら nil
    static func apply(to cgImage: CGImage) -> CrayonResult? {
        apply(canvas: CrayonFilter.canvas(for: cgImage))
    }

    static func apply(canvas: CrayonFilter.Canvas) -> CrayonResult? {
        let unit = canvas.unit
        let cellSize = max(max(canvas.subjectBox.width, canvas.subjectBox.height) / cellsAcrossSubject, 36 * unit)

        // 1. ガラスの色: ガラス片より小さい模様はぼかして消し、主役の色から作ったパレットで減色する
        let palette = CrayonFilter.makePalette(from: canvas.image, mask: canvas.mask, in: canvas.subjectBox, count: 10)
        let colors = canvas.image
            .applyingGaussianBlur(sigma: cellSize * 0.25)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.2])
            .applyingFilter("CIPalettize", parameters: [
                "inputPaletteImage": palette,
                "inputPerceptual": false,
            ])

        // 2. ガラス片と鉛の枠を Metal で描く（主役の外は透明）
        let params = Params(cellSize: Float(cellSize), leadWidth: Float(3.5 * unit), outlineWidth: Float(7 * unit))
        guard let glass = MetalPainter.run("stainedGlass", inputs: [
            .init(image: colors, kind: .color),
            .init(image: canvas.mask, kind: .gray),
        ], params: params, extent: canvas.extent) else { return nil }

        // 3. 紙の上に置く。3D 用には透明のまま使う（切り抜けたときだけ）
        let context = CrayonFilter.context
        let drawing = glass.composited(over: CIImage(color: CrayonFilter.paperColor))
        guard let drawingImage = context.createCGImage(drawing.cropped(to: canvas.extent), from: canvas.extent) else { return nil }
        let character = canvas.foreground.flatMap { _ in context.createCGImage(glass, from: canvas.extent) }
        return CrayonResult(drawing: drawingImage, character: character, photoCutout: canvas.photoCutout)
    }
}
