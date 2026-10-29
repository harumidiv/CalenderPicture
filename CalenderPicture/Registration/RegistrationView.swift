//
//  RegistrationView.swift
//  CalenderPicture
//
//  選んだ写真を、いま選ばれている塗り方の絵に変換し、確認してから登録する。
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct RegistrationView: View {
    let day: DayKey
    let item: PhotosPickerItem
    var onFinish: () -> Void

    private enum Phase {
        case converting
        case ready(EncodedEntryImages, drawing: UIImage, original: UIImage)
        case failed
    }

    @Environment(\.modelContext) private var modelContext
    @State private var phase = Phase.converting
    @State private var showsOriginal = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .navigationTitle(day.date().formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル", action: onFinish)
                            .accessibilityIdentifier("registration-cancel")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("登録", action: register)
                            .disabled(!isReady)
                            .accessibilityIdentifier("registration-register")
                    }
                }
                .alert("保存できませんでした", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                }
        }
        .interactiveDismissDisabled()
        .task { await convert() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .converting:
            ProgressView("\(PaintStyle.current.title)で描いています…")
        case .failed:
            ContentUnavailableView(
                "写真を変換できませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("別の写真を選んでください")
            )
        case .ready(_, let drawing, let original):
            VStack(spacing: 12) {
                Image(uiImage: showsOriginal ? original : drawing)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .onTapGesture { showsOriginal.toggle() }
                    .animation(.easeInOut(duration: 0.2), value: showsOriginal)
                Text(showsOriginal ? "元の写真（タップで\(PaintStyle.current.title)の絵）" : "タップで元の写真と見比べ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isReady: Bool {
        if case .ready = phase { true } else { false }
    }

    private func convert() async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            phase = .failed
            return
        }
        let result = await Task.detached(priority: .userInitiated) { () -> (EncodedEntryImages, UIImage, UIImage)? in
            // 表示用の画像もここで展開しておき、メインスレッドで展開しないようにする
            guard let images = EntryImageProcessor.process(data: data),
                  let drawing = UIImage(data: images.drawing)?.preparingForDisplay(),
                  let original = UIImage(data: images.original)?.preparingForDisplay()
            else { return nil }
            return (images, drawing, original)
        }.value
        if let (images, drawing, original) = result {
            phase = .ready(images, drawing: drawing, original: original)
        } else {
            phase = .failed
        }
    }

    private func register() {
        guard case .ready(let images, _, _) = phase else { return }
        do {
            try DiaryStore(context: modelContext).save(images, for: day)
            onFinish()
        } catch {
            saveFailed = true
        }
    }
}
