//
//  ShaderPaintFilter.swift
//  CalenderPicture
//
//  1 ピクセルずつ描ける塗り方（アニメ調・水彩など）を ShaderPaint.metal のカーネルで描く。
//  下ごしらえ（主役の切り抜き・明るさの補正）はクレヨンと共通。
//

import CoreImage

nonisolated enum ShaderPaintFilter {
    /// ShaderPaint.metal の ShaderPaintParams と同じ並び
    private struct Params {
        var size: SIMD2<Float>
        var scale: Float
    }

    /// 線の太さや模様の細かさを決めるときの基準の長辺（px）
    private static let referenceLongSide: CGFloat = 676

    /// `kernel` の名前のカーネルで描く。Metal が使えないなど、変換できなかったら nil
    static func apply(canvas: CrayonFilter.Canvas, kernel: String) -> CrayonResult? {
        let extent = canvas.extent
        let scale = max(extent.width, extent.height) / referenceLongSide

        // カーネルに渡す 4 枚: 写真 / 細かいノイズを消した写真 / 主役のマスク / ぼかしたマスク
        let soft = canvas.image.applyingGaussianBlur(sigma: 2 * scale)
        let softMask = canvas.mask.applyingGaussianBlur(sigma: 7 * scale)
        let params = Params(size: SIMD2(Float(extent.width), Float(extent.height)), scale: Float(scale))
        guard let painted = MetalPainter.run(kernel, inputs: [
            .init(image: canvas.image, kind: .color),
            .init(image: soft, kind: .color),
            .init(image: canvas.mask, kind: .gray),
            .init(image: softMask, kind: .gray),
        ], params: params, extent: extent) else { return nil }

        let context = CrayonFilter.context
        guard let drawing = context.createCGImage(painted, from: extent) else { return nil }
        // 3D 用には、描いた絵を主役の形に切り抜く（切り抜けたときだけ）
        let character = canvas.foreground.flatMap { _ in
            let cutout = painted.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.clear,
                kCIInputMaskImageKey: canvas.mask.applyingGaussianBlur(sigma: scale),
            ])
            return context.createCGImage(cutout.cropped(to: extent), from: extent)
        }
        return CrayonResult(drawing: drawing, character: character, photoCutout: canvas.photoCutout)
    }
}
