//
//  EntryImageProcessor.swift
//  CalenderPicture
//
//  登録する写真をクレヨン変換し、保存用のデータにする。数秒かかるのでメインスレッド外で呼ぶ。
//

import UIKit

nonisolated enum EntryImageProcessor {
    /// クレヨン変換に渡す写真の長辺
    static let crayonInputLongSide: CGFloat = 1200
    /// 保存する元写真の長辺
    static let originalLongSide: CGFloat = 2048
    /// 保存するキャラクター画像の長辺
    static let characterLongSide: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.85

    /// 写真ライブラリから読んだデータを変換する。フルサイズには展開せず、縮小しながら読み込む。失敗したら nil。
    static func process(data: Data) -> EncodedEntryImages? {
        guard let original = ImageDownsampler.downsample(data, maxPixelSize: originalLongSide) else { return nil }
        return process(original: original)
    }

    /// 変換・エンコードに失敗したら nil。
    static func process(_ image: UIImage) -> EncodedEntryImages? {
        guard let original = image.uprightCGImage(maxSize: originalLongSide) else { return nil }
        return process(original: original)
    }

    /// 元写真（向き補正・縮小済み）から変換入力を作って変換する。
    private static func process(original: CGImage) -> EncodedEntryImages? {
        guard let input = UIImage(cgImage: original).uprightCGImage(maxSize: crayonInputLongSide),
              let crayon = CrayonFilter.apply(to: input)
        else { return nil }
        return encode(original: original, crayon: crayon)
    }

    static func encode(original: CGImage, crayon: CrayonResult) -> EncodedEntryImages? {
        guard let drawing = UIImage(cgImage: crayon.drawing).jpegData(compressionQuality: jpegQuality),
              let originalData = UIImage(cgImage: original).jpegData(compressionQuality: jpegQuality)
        else { return nil }
        func png(_ image: CGImage?) -> Data? {
            image
                .flatMap { UIImage(cgImage: $0).uprightCGImage(maxSize: characterLongSide) }
                .flatMap { UIImage(cgImage: $0).pngData() }
        }
        return EncodedEntryImages(drawing: drawing, original: originalData,
                                  character: png(crayon.character), cutout: png(crayon.photoCutout))
    }
}
