//
//  ShareSheet.swift
//  CalenderPicture
//
//  シェアのプレビューシート。DOOD のように元写真を背景に敷き、その上にカードを重ねた画像を作って、
//  写真に保存・コピーする。共有ボタンでは、変換したクレヨン画そのものを渡す。
//

import SwiftUI
import UIKit

struct ShareSheet: View {
    let item: CardDeck.Item
    let photo: CardDeck.Photo
    var onClose: () -> Void

    @State private var images: (drawing: UIImage, original: UIImage)?
    /// 背景に元写真を敷くか（オフなら無地）
    @State private var showsPhoto = true
    /// 保存・コピーする書き出し済みの画像（写真の上にカードを重ねたもの）
    @State private var rendered: UIImage?
    @State private var toast: String?

    private var footnote: String {
        item.key.date().formatted(.dateTime.month().day().weekday(.abbreviated).locale(Locale(identifier: "ja_JP")))
    }

    var body: some View {
        VStack(spacing: 18) {
            preview
            actions
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DoodStyle.surface.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .capsule)
                    .padding(.bottom, 90)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityIdentifier("share-toast")
            }
        }
        .task(id: photo.version) {
            let drawing = photo.drawing, original = photo.original
            images = await Task.detached(priority: .userInitiated) {
                CardImageLoader.load(drawing: drawing, original: original)
            }.value
        }
        .task(id: RenderKey(loaded: images != nil, showsPhoto: showsPhoto)) {
            rendered = images.flatMap { render($0) }
        }
    }

    private struct RenderKey: Equatable {
        let loaded: Bool
        let showsPhoto: Bool
    }

    private var preview: some View {
        Group {
            if let images {
                SharePoster(drawing: images.drawing, original: showsPhoto ? images.original : nil, footnote: footnote)
            } else {
                Color(.secondarySystemFill).overlay { ProgressView() }
            }
        }
        .aspectRatio(SharePoster.aspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 28))
        // ボタンはプレビュー画像の角から内側に置く（外側の枠に合わせると、縮んだ画像の上端からはみ出す）
        .overlay(alignment: .topLeading) {
            Button(action: onClose) { overlayIcon("xmark") }
                .accessibilityLabel("閉じる")
                .accessibilityIdentifier("share-close")
                .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showsPhoto.toggle() } } label: {
                overlayIcon(showsPhoto ? "photo" : "photo.badge.minus")
            }
            .accessibilityLabel(showsPhoto ? "背景の写真をはずす" : "背景に写真を敷く")
            .accessibilityIdentifier("share-background")
            .padding(14)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// プレビューに重ねる半透明の丸いボタン
    private func overlayIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(.black.opacity(0.35), in: .circle)
            .contentShape(.circle)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Group {
                if let drawing = images?.drawing {
                    let image = Image(uiImage: drawing)
                    ShareLink(item: image, preview: SharePreview(footnote, image: image)) {
                        CircleIcon(systemName: "square.and.arrow.up", size: 50, isProminent: true)
                    }
                } else {
                    CircleIcon(systemName: "square.and.arrow.up", size: 50, isProminent: true)
                        .opacity(0.4)
                }
            }
            .accessibilityLabel("クレヨン画を共有")
            .accessibilityIdentifier("share-link")

            Group {
                Button("保存", systemImage: "square.and.arrow.down", action: save)
                    .buttonStyle(.pill)
                    .accessibilityIdentifier("share-save")
                Button("コピー", systemImage: "doc.on.doc") {
                    guard let rendered else { return }
                    UIPasteboard.general.image = rendered
                    show("コピーしました")
                }
                .buttonStyle(.pill)
                .accessibilityIdentifier("share-copy")
            }
            .disabled(rendered == nil)
        }
    }

    private func render(_ images: (drawing: UIImage, original: UIImage)) -> UIImage? {
        let poster = SharePoster(drawing: images.drawing, original: showsPhoto ? images.original : nil, footnote: footnote)
            .frame(width: SharePoster.renderSize.width, height: SharePoster.renderSize.height)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        return renderer.uiImage
    }

    private func save() {
        guard let rendered else { return }
        Task { show(await PhotoSaver.save(rendered)) }
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if toast == message { withAnimation { toast = nil } }
        }
    }
}

/// シェアする画像: 元写真（または無地）の上に、カードを中央に重ねる
struct SharePoster: View {
    static let aspectRatio: CGFloat = 9 / 16
    /// 書き出すときの大きさ（pt）。3倍で書き出すので 1080×1920px
    static let renderSize = CGSize(width: 360, height: 640)

    let drawing: UIImage
    let original: UIImage?
    let footnote: String

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.62
            ZStack {
                if let original {
                    Image(uiImage: original)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Color(red: 0.95, green: 0.95, blue: 0.96)
                }

                VStack(spacing: 6) {
                    Image(uiImage: drawing).resizable().scaledToFit()
                    Text(footnote)
                        .font(.system(size: cardWidth * 0.06, design: .rounded))
                        .foregroundStyle(Color(white: 0.4))
                        .lineLimit(1)
                }
                .padding(.horizontal, cardWidth * 0.03)
                .padding(.vertical, cardWidth * 0.06)
                .frame(width: cardWidth, height: cardWidth / CardDeck.cardAspectRatio)
                .background(Color(red: 0.98, green: 0.975, blue: 0.965), in: .rect(cornerRadius: cardWidth * 0.08))
                .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .environment(\.colorScheme, .light)
    }
}
