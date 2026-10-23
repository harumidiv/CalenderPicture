//
//  ContentView.swift
//  CalenderPicture
//
//  Created by harumi.sagawa on 2026/10/23.
//

import PhotosUI
import SwiftData
import SwiftUI

/// 写真を選んだあとの登録シートの内容
struct PendingRegistration: Identifiable {
    let id = UUID()
    let day: DayKey
    let item: PhotosPickerItem
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    /// 写真を選んで登録する先の日。ピッカーが閉じたあとに選択結果が届くので、表示状態とは別に持つ
    @State private var pickingDay: DayKey?
    @State private var isPickerPresented = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var registration: PendingRegistration?
    @State private var openedDay: DayKey?
    @State private var wanderMonth: MonthGrid?

    var body: some View {
        CalendarView(
            onSelectEmptyDay: { day in
                pickingDay = day
                isPickerPresented = true
            },
            onSelectEntry: { openedDay = $0 },
            onOpenWander: { wanderMonth = $0 }
        )
        .photosPicker(isPresented: $isPickerPresented, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item, let day = pickingDay else { return }
            registration = PendingRegistration(day: day, item: item)
            pickedItem = nil
            pickingDay = nil
        }
        .sheet(item: $registration) { pending in
            RegistrationView(day: pending.day, item: pending.item) { registration = nil }
        }
        .fullScreenCover(item: $openedDay) { day in
            CardPagerView(initialDay: day) { openedDay = nil }
        }
        .fullScreenCover(item: $wanderMonth) { month in
            WanderView(month: month) { wanderMonth = nil }
        }
        #if DEBUG
        .task {
            // UI テスト用: 起動引数 -resetStore で保存済みの写真をすべて消す
            if ProcessInfo.processInfo.arguments.contains("-resetStore") {
                let store = DiaryStore(context: modelContext)
                for key in store.allKeys() { try? store.delete(key) }
            }
            if SampleEntries.isRequested {
                await SampleEntries.seed(into: DiaryStore(context: modelContext))
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
