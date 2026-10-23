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

    @Query private var entries: [DiaryEntry]
    @State private var month = MonthGrid(containing: .today())

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let entriesByKey = Dictionary(entries.map { ($0.dayKey, $0) }, uniquingKeysWith: { first, _ in first })
        let today = DayKey.today()

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

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(month.cells().enumerated()), id: \.offset) { _, key in
                    if let key {
                        let entry = entriesByKey[key.string]
                        DayCell(day: key.day, drawingData: entry?.drawingData, version: entry?.updatedAt, isToday: key == today)
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .contentShape(.rect)
        .gesture(
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
        withAnimation(.snappy) { month = month.adding(months: months) }
    }
}
