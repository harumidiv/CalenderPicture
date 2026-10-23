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

    /// その月で `order` 番目（0 始まり）に貼るシールの待ち時間。
    static func delay(order: Int) -> Double {
        firstDelay + interval * Double(order)
    }

    /// 貼る順番（0 始まり）。`seed` ごとにランダムに並べ替える。同じ `seed` なら毎回同じ順番になるので、
    /// 表示のあいだは種を固定し、月を表示し直すたびに種を変える。
    static func order(of keys: [DayKey], seed: UInt64) -> [DayKey: Int] {
        var generator = SplitMix64(state: seed)
        let shuffled = keys.sorted().shuffled(using: &generator)
        return Dictionary(uniqueKeysWithValues: shuffled.enumerated().map { ($1, $0) })
    }

    /// 種から決まる乱数（SplitMix64）
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// 貼ったあとの傾き（度）。日ごとに決まった向きで ±3 度以内。
    static func tilt(for key: DayKey) -> Double {
        // 日付から決まる簡単なハッシュ（起動ごとに変わる hashValue は使わない）
        let seed = (key.year * 372 + key.month * 31 + key.day) &* 2_654_435_761
        return Double(abs(seed) % 61 - 30) / 10
    }
}
