//
//  ContentView.swift
//  CalenderPicture
//
//  Created by harumi.sagawa on 2026/10/23.
//
//  最初の画面。DOOD のように、上に日付のピルとメニュー、中央にカードの山、下にアクションを並べる。
//  起動時に塗り方（PaintStyle）を選ぶシートを出す。カレンダーとシェアもシートで開く。左上のボタンで、写真が未登録の日もカードとして山に混ぜられる（タップで追加）。
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.dayKey) private var entries: [DiaryEntry]
    /// 山の一番上に出ている日。未選択・削除済みのときは `defaultDay` を出す
    @State private var selection: DayKey?
    @State private var photoRequest: PhotoRequest?
    @State private var showsCalendar = false
    @State private var sharing: CardDeck.Item?
    @State private var confirmsDelete = false
    /// 未登録の日も山に混ぜるか（次に開いたときも覚えておく）
    @AppStorage("showsEmptyDays") private var showsEmptyDays = false
    /// 起動時に塗り方を選ばせる。起動引数 -paintStyle で指定されたとき（UI テストなど）は出さない
    @State private var choosesPaintStyle = !ProcessInfo.processInfo.arguments.contains("-\(PaintStyle.storageKey)")

    /// 山に積むカード（日付の昇順）。未登録の日も混ぜるときは、一番古い登録（少なくとも今月の1日）から今日までの毎日
    private var items: [CardDeck.Item] {
        let photos = Dictionary(
            entries.map { ($0.key, CardDeck.Photo(drawing: $0.drawingData, original: $0.originalData, version: $0.updatedAt)) },
            uniquingKeysWith: { first, _ in first }
        )
        guard showsEmptyDays else {
            return entries.map { CardDeck.Item(key: $0.key, photo: photos[$0.key]) }
        }
        let today = DayKey.today()
        let monthStart = DayKey(year: today.year, month: today.month, day: 1)
        let start = min(entries.first?.key ?? monthStart, monthStart)
        // 未来の日に登録してあれば、それも山に入れる
        let days = Set(DayKey.days(from: start, through: today)).union(photos.keys).sorted()
        return days.map { CardDeck.Item(key: $0, photo: photos[$0]) }
    }

    /// 選んでいない間に出す日: 今日までで一番新しい日（未来の日しかなければ一番新しい日）
    private var defaultDay: DayKey? {
        let today = DayKey.today()
        return entries.last { $0.key <= today }?.key ?? entries.last?.key
    }

    /// いま表に出ている日（山が空なら nil）。未登録の日も混ぜているときは、登録がなければ今日
    private func current(in items: [CardDeck.Item]) -> DayKey? {
        if let selection, items.contains(where: { $0.key == selection }) { return selection }
        return defaultDay ?? (showsEmptyDays ? .today() : nil)
    }

    var body: some View {
        let items = items
        let current = current(in: items)
        let currentPhoto = items.first { $0.key == current }?.photo

        VStack(spacing: 0) {
            header(current: current, hasPhoto: currentPhoto != nil)

            Group {
                if let current {
                    CardDeck(items: items, selection: Binding(get: { current }, set: { selection = $0 }),
                             onAddPhoto: { photoRequest = PhotoRequest(day: $0) })
                } else {
                    emptyCard
                }
            }
            .padding(.vertical, 28)

            actions(current: current, items: items)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DoodStyle.background.ignoresSafeArea())
        .photoRegistration($photoRequest)
        .confirmationDialog("この日の写真を削除しますか？", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive, action: deleteCurrent)
                .accessibilityIdentifier("card-delete-confirm")
        }
        .sheet(isPresented: $showsCalendar) {
            CalendarView(
                onSelectEntry: { day in
                    selection = day
                    showsCalendar = false
                },
                onClose: { showsCalendar = false }
            )
        }
        .sheet(isPresented: $choosesPaintStyle) {
            PaintStylePicker { choosesPaintStyle = false }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $sharing) { item in
            if let photo = item.photo {
                ShareSheet(item: item, photo: photo) { sharing = nil }
            }
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

    private func header(current: DayKey?, hasPhoto: Bool) -> some View {
        let day = current ?? .today()
        return ZStack {
            HStack {
                // 未登録の日もカードにして山に混ぜる
                Button {
                    withAnimation(.spring(duration: 0.35)) { showsEmptyDays.toggle() }
                } label: {
                    CircleIcon(systemName: showsEmptyDays ? "rectangle.stack.fill.badge.plus" : "rectangle.stack.badge.plus",
                               isProminent: showsEmptyDays)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("写真のない日も表示")
                .accessibilityValue(showsEmptyDays ? "オン" : "オフ")
                .accessibilityIdentifier("toggle-empty-days")
                Spacer()
            }

            // 日付のピルを押すとカレンダーを開く
            Button { showsCalendar = true } label: {
                Text(day.date().formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(DoodStyle.surface, in: .capsule)
                    .shadow(color: DoodStyle.shadowColor, radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(day.date().formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
            .accessibilityHint("カレンダーを開く")
            .accessibilityIdentifier("card-date")

            HStack {
                Spacer()
                Menu {
                    Button("カレンダー", systemImage: "calendar") { showsCalendar = true }
                        .accessibilityIdentifier("menu-calendar")
                    Button("塗り方を選ぶ", systemImage: "paintbrush") { choosesPaintStyle = true }
                        .accessibilityIdentifier("menu-paint-style")
                    if hasPhoto {
                        Button("この日の写真を削除", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                            .accessibilityIdentifier("card-delete")
                    }
                } label: {
                    CircleIcon(systemName: "ellipsis")
                }
                .accessibilityLabel("メニュー")
                .accessibilityIdentifier("home-menu")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// まだ1枚も登録がないときに、山の代わりに置く白いカード
    private var emptyCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(DoodStyle.surface)
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "scribble.variable")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("写真を1枚選ぶと\nらくがきの絵日記になります")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .aspectRatio(CardDeck.cardAspectRatio, contentMode: .fit)
            .containerRelativeFrame(.horizontal) { width, _ in width * CardDeck.cardWidthRatio }
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home-empty")
    }

    private func actions(current: DayKey?, items: [CardDeck.Item]) -> some View {
        let item = items.first { $0.key == current }
        return HStack(spacing: 10) {
            if let current, item?.photo == nil {
                Button("写真を追加", systemImage: "photo.badge.plus") { photoRequest = PhotoRequest(day: current) }
                    .buttonStyle(.prominentPill)
                    .accessibilityIdentifier("card-add")
            } else if let current {
                Button("写真を変更", systemImage: "arrow.clockwise") { photoRequest = PhotoRequest(day: current) }
                    .buttonStyle(.pill)
                    .accessibilityIdentifier("card-change")
                Button("シェア", systemImage: "square.and.arrow.up") { sharing = item }
                .buttonStyle(.prominentPill)
                .accessibilityIdentifier("card-share")
            } else {
                Button("写真を選ぶ", systemImage: "photo.badge.plus") { photoRequest = PhotoRequest(day: .today()) }
                    .buttonStyle(.prominentPill)
                    .accessibilityIdentifier("home-add")
            }
        }
    }

    private func deleteCurrent() {
        guard let deleted = current(in: items) else { return }
        // 未登録の日も混ぜているときは、消した日は空のカードとしてその場に残る
        if !showsEmptyDays {
            let next = CardNavigation.neighborAfterDeleting(deleted, in: entries.map(\.key))
            withAnimation(.spring(duration: 0.35)) { selection = next }
        }
        try? DiaryStore(context: modelContext).delete(deleted)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
}
