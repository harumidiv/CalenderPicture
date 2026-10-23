//
//  CardPagerView.swift
//  CalenderPicture
//
//  登録済みの日をカードの山で表示する。左右スワイプで前後の登録済みの日へめくる。
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CardPagerView: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.dayKey) private var entries: [DiaryEntry]
    /// いま一番上に出ているカードの日
    @State private var selection: DayKey
    @State private var confirmsDelete = false
    @State private var isPickerPresented = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var registration: PendingRegistration?

    init(initialDay: DayKey, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _selection = State(initialValue: initialDay)
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            CardDeck(
                items: entries.map { .init(key: $0.key, drawing: $0.drawingData, original: $0.originalData, version: $0.updatedAt) },
                selection: $selection
            )

            actions
        }
        .padding(.vertical)
        .background(Color(white: 0.94))
        .confirmationDialog("この日の写真を削除しますか？", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive, action: deleteCurrent)
                .accessibilityIdentifier("card-delete-confirm")
        }
        .photosPicker(isPresented: $isPickerPresented, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            registration = PendingRegistration(day: selection, item: item)
            pickedItem = nil
        }
        .sheet(item: $registration) { pending in
            RegistrationView(day: pending.day, item: pending.item) { registration = nil }
        }
    }

    private var header: some View {
        ZStack {
            Text(selection.date().formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                .font(.title3.weight(.bold))
                .accessibilityIdentifier("card-date")
            HStack {
                Spacer()
                Button("閉じる", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .accessibilityIdentifier("card-close")
            }
        }
        .padding(.horizontal, 24)
    }

    private var actions: some View {
        HStack(spacing: 16) {
            Button("写真を変更", systemImage: "photo.badge.arrow.down") { isPickerPresented = true }
                .accessibilityIdentifier("card-change")
            Button("削除", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                .accessibilityIdentifier("card-delete")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func deleteCurrent() {
        let deleted = selection
        let next = CardNavigation.neighborAfterDeleting(deleted, in: entries.map(\.key))
        if let next { withAnimation(.spring(duration: 0.35)) { selection = next } }
        try? DiaryStore(context: modelContext).delete(deleted)
        if next == nil { onClose() }
    }
}

/// 1日分のカード。画像のデコードは非同期で行う。
/// 裏返しの状態はカードごとに持つ。
struct CardPage: View {
    let key: DayKey
    let drawingData: Data
    let originalData: Data
    let version: Date
    let isCurrent: Bool

    @State private var isFlipped = false

    @State private var images: (drawing: UIImage, original: UIImage)?

    var body: some View {
        Group {
            if let images {
                // 山の下に重なっているカードは読み上げない
                FlipCard(front: Image(uiImage: images.drawing), back: Image(uiImage: images.original),
                         isFlipped: $isFlipped, isAccessible: isCurrent,
                         footnote: key.date().formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP"))))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // ほかの日へ移ったら表に戻す（隣の日のカードは山の中に残り続けるので onDisappear では戻らない）
        .onChange(of: isCurrent) { _, current in
            if !current { isFlipped = false }
        }
        .task(id: version) {
            let drawingData = drawingData, originalData = originalData
            images = await Task.detached(priority: .userInitiated) {
                CardImageLoader.load(drawing: drawingData, original: originalData)
            }.value
        }
    }
}
