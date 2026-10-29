//
//  PaintStyleComparison.swift
//  CalenderPicture
//
//  1 枚の写真をすべての塗り方で描いて並べ、見比べてから塗り方を選ぶ画面。
//  主役の切り抜きなどの下ごしらえは 1 回だけ行い、塗り方ごとに描けたものから順に出す。
//

import PhotosUI
import SwiftUI
import UIKit

struct PaintStyleComparison: View {
    let current: PaintStyle
    let onChoose: (PaintStyle) -> Void
    let onClose: () -> Void

    private enum Preview {
        case image(UIImage)
        case failed
    }

    @State private var item: PhotosPickerItem?
    @State private var previews: [PaintStyle: Preview] = [:]
    @State private var loadFailed = false
    /// 大きく表示して横にめくっている塗り方
    @State private var focused: PaintStyle?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DoodStyle.background.ignoresSafeArea())
                .navigationTitle("塗り方を見比べる")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる", action: onClose)
                            .accessibilityIdentifier("comparison-close")
                    }
                    if item != nil {
                        ToolbarItem(placement: .primaryAction) {
                            PhotosPicker(selection: $item, matching: .images) {
                                Label("写真を変える", systemImage: "photo.on.rectangle")
                            }
                            .accessibilityIdentifier("comparison-change-photo")
                        }
                    }
                }
        }
        .task(id: item) { await render(item) }
        .sheet(item: $focused) { style in
            PaintStylePager(initial: style, previews: previews.compactMapValues {
                if case .image(let image) = $0 { image } else { nil }
            }) { chosen in
                focused = nil
                onChoose(chosen)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if item == nil {
            ContentUnavailableView {
                Label("写真を1枚選んでください", systemImage: "photo")
            } description: {
                Text("すべての塗り方で描いて並べます。気に入ったものをタップすると大きく見られます")
            } actions: {
                PhotosPicker(selection: $item, matching: .images) {
                    Label("写真を選ぶ", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.prominentPill)
                .accessibilityIdentifier("comparison-pick-photo")
            }
        } else if loadFailed {
            ContentUnavailableView(
                "写真を読み込めませんでした",
                systemImage: "exclamationmark.triangle",
                description: Text("別の写真を選んでください")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(PaintStyle.allCases) { style in
                        Button { focused = style } label: { tile(style) }
                            .buttonStyle(.plain)
                            .disabled(!isDrawn(style))
                            .accessibilityIdentifier("comparison-\(style.rawValue)")
                    }
                }
                .padding(20)
            }
        }
    }

    private func isDrawn(_ style: PaintStyle) -> Bool {
        if case .image = previews[style] { true } else { false }
    }

    private func tile(_ style: PaintStyle) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                DoodStyle.surface
                switch previews[style] {
                case .image(let image):
                    Image(uiImage: image).resizable().scaledToFit()
                case .failed:
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                case nil:
                    ProgressView()
                }
            }
            .aspectRatio(CardDeck.cardAspectRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: DoodStyle.shadowColor, radius: 8, y: 3)

            HStack(spacing: 4) {
                Text(style.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                if style == current {
                    Image(systemName: "checkmark.circle.fill").font(.caption)
                        .accessibilityLabel("いまの塗り方")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 写真を読み込み、下ごしらえを 1 回だけしてから、塗り方ごとに描けた順に previews へ入れる
    private func render(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        previews = [:]
        loadFailed = false
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            if !Task.isCancelled { loadFailed = true }
            return
        }
        let results = AsyncStream<(PaintStyle, UIImage?)> { continuation in
            let task = Task.detached(priority: .userInitiated) {
                guard let input = EntryImageProcessor.paintInput(data: data) else {
                    continuation.finish()
                    return
                }
                let canvas = CrayonFilter.canvas(for: input)
                for style in PaintStyle.allCases where !Task.isCancelled {
                    // 表示用の展開もここで済ませ、メインスレッドで展開しないようにする
                    let image = style.paint(canvas).map { UIImage(cgImage: $0.drawing).preparingForDisplay() ?? UIImage(cgImage: $0.drawing) }
                    continuation.yield((style, image))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        var received = 0
        for await (style, image) in results {
            previews[style] = image.map(Preview.image) ?? .failed
            received += 1
        }
        if received == 0, !Task.isCancelled { loadFailed = true }
    }
}

/// 描いた絵を大きく出し、横にめくって見比べる
private struct PaintStylePager: View {
    let previews: [PaintStyle: UIImage]
    let onChoose: (PaintStyle) -> Void
    @State private var selection: PaintStyle

    init(initial: PaintStyle, previews: [PaintStyle: UIImage], onChoose: @escaping (PaintStyle) -> Void) {
        self.previews = previews
        self.onChoose = onChoose
        _selection = State(initialValue: initial)
    }

    private var styles: [PaintStyle] { PaintStyle.allCases.filter { previews[$0] != nil } }

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $selection) {
                ForEach(styles) { style in
                    if let image = previews[style] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            .padding(.horizontal, 24)
                            .tag(style)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 4) {
                Text(selection.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(selection.subtitle)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Button("この塗り方にする", systemImage: "checkmark") { onChoose(selection) }
                .buttonStyle(.prominentPill)
                .accessibilityIdentifier("comparison-choose")
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DoodStyle.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
