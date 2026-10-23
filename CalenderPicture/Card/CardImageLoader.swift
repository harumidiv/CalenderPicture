//
//  CardImageLoader.swift
//  CalenderPicture
//
//  カード表示用の画像を、メインスレッド外で縮小・展開まで済ませて用意する。
//

import UIKit

nonisolated enum CardImageLoader {
    /// カードに出す元写真の長辺。画面のカード幅（3x で約 1100px）に足りる大きさに抑えてメモリを節約する
    static let maxPixelSize: CGFloat = 1600

    static func load(drawing: Data, original: Data) -> (drawing: UIImage, original: UIImage)? {
        guard let drawingImage = ImageDownsampler.downsample(drawing, maxPixelSize: maxPixelSize),
              let originalImage = ImageDownsampler.downsample(original, maxPixelSize: maxPixelSize)
        else { return nil }
        return (UIImage(cgImage: drawingImage), UIImage(cgImage: originalImage))
    }
}
