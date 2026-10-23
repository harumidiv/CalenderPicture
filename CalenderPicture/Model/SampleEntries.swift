//
//  SampleEntries.swift
//  CalenderPicture
//
//  動作確認用のサンプル。起動引数 -seedSampleEntries で今月にいくつか登録する（DEBUG のみ）。
//

#if DEBUG
import UIKit

enum SampleEntries {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-seedSampleEntries")
    }

    static func seed(into store: DiaryStore) async {
        let today = DayKey.today()
        let days = Set([3, 10, 17, today.day]).sorted()
        for (index, day) in days.enumerated() {
            let key = DayKey(year: today.year, month: today.month, day: day)
            guard store.entry(for: key) == nil else { continue }
            let hue = CGFloat(index) / CGFloat(days.count)
            let images = await Task.detached(priority: .userInitiated) { () -> EncodedEntryImages? in
                guard let images = EntryImageProcessor.process(UIImage(cgImage: makePhoto(hue: hue))) else { return nil }
                // シミュレータでは被写体を切り抜けずキャラクターが作られないので、確認用の透明なキャラクターを入れる
                return EncodedEntryImages(
                    drawing: images.drawing,
                    original: images.original,
                    character: images.character ?? UIImage(cgImage: makeCharacter(hue: hue)).pngData()
                )
            }.value
            if let images { try? store.save(images, for: key) }
        }
    }

    /// 透明な背景に、目のある丸い主役と足だけを描いたキャラクター画像（余白つき）
    nonisolated private static func makeCharacter(hue: CGFloat) -> CGImage {
        let size = CGSize(width: 600, height: 760)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor(hue: hue, saturation: 0.75, brightness: 0.9, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 100, y: 80, width: 400, height: 460))
            UIBezierPath(roundedRect: CGRect(x: 190, y: 500, width: 80, height: 170), cornerRadius: 35).fill()
            UIBezierPath(roundedRect: CGRect(x: 330, y: 500, width: 80, height: 170), cornerRadius: 35).fill()
            UIColor.white.setFill()
            cg.fillEllipse(in: CGRect(x: 200, y: 220, width: 80, height: 90))
            cg.fillEllipse(in: CGRect(x: 320, y: 220, width: 80, height: 90))
            UIColor.black.setFill()
            cg.fillEllipse(in: CGRect(x: 225, y: 250, width: 40, height: 45))
            cg.fillEllipse(in: CGRect(x: 345, y: 250, width: 40, height: 45))
        }.cgImage!
    }

    /// 背景に色の帯、中央に丸い主役がいる写真風の画像
    nonisolated private static func makePhoto(hue: CGFloat) -> CGImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hue: hue, saturation: 0.25, brightness: 0.9, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hue: hue + 0.5, saturation: 0.3, brightness: 0.7, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 850, width: 900, height: 350))
            // 左右の反転に気づけるよう、左上だけに印を置く
            UIColor.black.setFill()
            context.fill(CGRect(x: 60, y: 60, width: 160, height: 160))
            UIColor(hue: hue, saturation: 0.8, brightness: 0.85, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 250, y: 350, width: 400, height: 500))
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 340, y: 480, width: 80, height: 90))
            context.cgContext.fillEllipse(in: CGRect(x: 480, y: 480, width: 80, height: 90))
            UIColor.black.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 365, y: 510, width: 40, height: 45))
            context.cgContext.fillEllipse(in: CGRect(x: 505, y: 510, width: 40, height: 45))
        }.cgImage!
    }
}
#endif
