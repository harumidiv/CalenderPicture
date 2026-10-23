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
            let images = await Task.detached(priority: .userInitiated) {
                EntryImageProcessor.process(UIImage(cgImage: makePhoto(hue: hue)))
            }.value
            if let images { try? store.save(images, for: key) }
        }
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
