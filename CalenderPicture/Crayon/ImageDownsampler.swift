//
//  ImageDownsampler.swift
//  CalenderPicture
//
//  写真データを、フルサイズに展開せずに縮小して読み込む（48MP などの大きな写真でもメモリを使いすぎない）。
//

import CoreGraphics
import Foundation
import ImageIO

nonisolated enum ImageDownsampler {
    /// EXIF の向きを反映し、長辺が `maxPixelSize` 以下になるように縮小した画像。小さい画像は拡大しない。
    static func downsample(_ data: Data, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
