//
//  StickerMotion.swift
//  CalenderPicture
//
//  カレンダーのサムネイルを、シールのように上から1枚ずつペタッと貼る動きの値。
//

import Foundation

nonisolated enum StickerMotion {
    /// 画面が出てから最初の1枚を貼るまでの待ち時間（秒）
    static let firstDelay = 0.25
    /// 1枚ごとにずらす時間（秒）
    static let interval = 0.1

    /// その月で `order` 番目（日付の早い順、0 始まり）に貼るシールの待ち時間。
    static func delay(order: Int) -> Double {
        firstDelay + interval * Double(order)
    }

    /// 貼ったあとの傾き（度）。日ごとに決まった向きで ±3 度以内。
    static func tilt(for key: DayKey) -> Double {
        // 日付から決まる簡単なハッシュ（起動ごとに変わる hashValue は使わない）
        let seed = (key.year * 372 + key.month * 31 + key.day) &* 2_654_435_761
        return Double(abs(seed) % 61 - 30) / 10
    }
}
