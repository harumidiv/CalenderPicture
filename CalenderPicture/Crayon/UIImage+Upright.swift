//
//  UIImage+Upright.swift
//  CalenderPicture（ImageTransrator から移植）
//

import UIKit

nonisolated extension UIImage {
    /// 向き情報を反映し、指定サイズ以下に縮小した CGImage を返す
    func uprightCGImage(maxSize: CGFloat) -> CGImage? {
        let ratio = min(1, maxSize / max(size.width, size.height))
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }
}
