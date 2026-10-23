//
//  CalendarView.swift
//  CalenderPicture
//
//  月表示のカレンダー。登録済みの日はクレヨン画のサムネイルを表示する。
//

import SwiftData
import SwiftUI

struct CalendarView: View {
    var onSelectEmptyDay: (DayKey) -> Void
    var onSelectEntry: (DayKey) -> Void
    var onOpenWander: (MonthGrid) -> Void

    @Query private var entries: [DiaryEntry]
    @State private var month = MonthGrid(containing: .today())
    /// シールを貼る順番の乱数の種。月を表示し直すたびに変える
    @State private var stickerSeed = UInt64.random(in: .min ... .max)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let entriesByKey = Dictionary(entries.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
        let today = DayKey.today()
        // この月で登録済みの日を、ランダムな順にシールを貼る
        let stickerOrder = StickerMotion.order(
            of: month.cells().compactMap { $0 }.filter { entriesByKey[$0.string] != nil },
            seed: stickerSeed
        )

        VStack(spacing: 12) {
            header

            HStack(spacing: 4) {
                ForEach(Array(month.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 横向きや iPad では6行が画面に収まらないので、グリッドは縦にスクロールできるようにする
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(month.cells().enumerated()), id: \.offset) { _, key in
                        if let key {
                            let entry = entriesByKey[key.string]
                            DayCell(
                                day: key.day,
                                drawingData: entry?.drawingData,
                                version: entry?.updatedAt,
                                isToday: key == today,
                                stickerDelay: StickerMotion.delay(order: stickerOrder[key] ?? 0),
                                stickerTilt: StickerMotion.tilt(for: key)
                            )
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(key.month)月\(key.day)日")
                                .accessibilityValue(entry == nil ? "未登録" : "登録済み")
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("day-\(key.string)")
                                .onTapGesture {
                                    if entry != nil { onSelectEntry(key) } else { onSelectEmptyDay(key) }
                                }
                        } else {
                            Color.clear.aspectRatio(DayCell.aspectRatio, contentMode: .fit)
                        }
                    }
                }
                .id(month)
                .transition(.opacity)
                .padding(.bottom, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("この月のキャラクターを動かす", systemImage: "figure.walk") { onOpenWander(month) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .accessibilityIdentifier("open-wander")
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .contentShape(.rect)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    move(by: value.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private var header: some View {
        HStack {
            Button("前の月", systemImage: "chevron.left") { move(by: -1) }
                .labelStyle(.iconOnly)
            Spacer()
            Text(month.title)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
            Spacer()
            Button("次の月", systemImage: "chevron.right") { move(by: 1) }
                .labelStyle(.iconOnly)
        }
        .font(.title3)
        .padding(.horizontal, 8)
    }

    private func move(by months: Int) {
        stickerSeed = UInt64.random(in: .min ... .max)
        withAnimation(.snappy) { month = month.adding(months: months) }
    }
}
