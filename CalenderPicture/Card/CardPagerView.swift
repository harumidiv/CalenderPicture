//
//  CardPagerView.swift
//  CalenderPicture
//
//  登録済みの日をカードで1枚ずつ表示する。左右スワイプで前後の登録済みの日へめくる。
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CardPagerView: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DiaryEntry.dayKey) private var entries: [DiaryEntry]
    private let initialDay: DayKey
    /// いま表示しているページの日（スクロール位置と連動）
    @State private var scrolledDay: DayKey?
    @State private var confirmsDelete = false
    @State private var isPickerPresented = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var registration: PendingRegistration?

    init(initialDay: DayKey, onClose: @escaping () -> Void) {
        self.onClose = onClose
        self.initialDay = initialDay
    }

    private var selection: DayKey { scrolledDay ?? initialDay }

    var body: some View {
        VStack(spacing: 16) {
            header

            // TabView のページ表示はスワイプ途中で止まることがあったため、ScrollView のページングを使う
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(entries, id: \.key) { entry in
                        // 削除済みのモデルを非同期処理から触らないよう、値を取り出して渡す
                        CardPage(
                            drawingData: entry.drawingData,
                            originalData: entry.originalData,
                            version: entry.updatedAt,
                            isCurrent: entry.key == selection
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledDay)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("card-pager")
            // 初期値で位置を渡すと、途中のページから開いたときに最初のスワイプが元のページに戻されるため、表示後に移動する
            .onAppear { scrolledDay = initialDay }

            actions
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
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
        if let next { withAnimation { scrolledDay = next } }
        try? DiaryStore(context: modelContext).delete(deleted)
        if next == nil { onClose() }
    }
}

/// 1日分のカード。画像のデコードは非同期で行う。
/// 裏返しの状態はカードごとに持つ（全ページで共有すると、めくった瞬間に全カードが回ってスクロールを妨げる）。
private struct CardPage: View {
    let drawingData: Data
    let originalData: Data
    let version: Date
    let isCurrent: Bool

    @State private var isFlipped = false

    @State private var images: (drawing: UIImage, original: UIImage)?

    var body: some View {
        Group {
            if let images {
                FlipCard(front: Image(uiImage: images.drawing), back: Image(uiImage: images.original), isFlipped: $isFlipped)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // ほかのページへ移ったら表に戻す（隣のページは保持され続けるので onDisappear では戻らない）
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
