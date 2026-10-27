//
//  MonthShareSheet.swift
//  CalenderPicture
//
//  1か月ぶんのらくがきを、カレンダーの形に並べた1枚の画像にして共有する。
//  登録した日はその日のマスにシールのように少し傾けて貼り、未登録の日は薄い数字だけを置く。
//

import SwiftUI
import UIKit

/// 1日ぶんの貼る絵（削除済みのモデルを非同期処理から触らないよう値で持つ）
struct MonthSticker: Sendable {
    let data: Data
    /// 背景の透明なキャラクターか（false なら紙の背景つきのクレヨン画）
    let isCutout: Bool
}

/// 共有するひと月ぶん
struct MonthShare: Identifiable {
    let month: MonthGrid
    let stickers: [DayKey: MonthSticker]
    var id: String { month.id }
}

struct MonthShareSheet: View {
    let share: MonthShare
    var onClose: () -> Void

    @State private var images: [DayKey: UIImage]?
    @State private var rendered: UIImage?
    @State private var toast: String?

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
                    .accessibilityIdentifier("month-share-toast")
            }
        }
        .task {
            let stickers = share.stickers
            let loaded = await Task.detached(priority: .userInitiated) {
                stickers.compactMapValues { sticker in
                    ImageDownsampler.downsample(sticker.data, maxPixelSize: MonthPoster.stickerPixelSize).map(UIImage.init(cgImage:))
                }
            }.value
            images = loaded
            let renderer = ImageRenderer(content: poster(loaded)
                .frame(width: MonthPoster.renderSize.width, height: MonthPoster.renderSize.height))
            renderer.scale = 3
            rendered = renderer.uiImage
        }
    }

    private func poster(_ images: [DayKey: UIImage]) -> MonthPoster {
        MonthPoster(month: share.month, images: images, cutouts: Set(share.stickers.filter(\.value.isCutout).keys))
    }

    private var preview: some View {
        Group {
            if let images {
                poster(images)
            } else {
                Color(.secondarySystemFill).overlay { ProgressView() }
            }
        }
        .aspectRatio(MonthPoster.renderSize.width / MonthPoster.renderSize.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 24))
        .shadow(color: DoodStyle.shadowColor, radius: 12, y: 4)
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.35), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            .accessibilityIdentifier("month-share-close")
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Group {
                if let rendered {
                    let image = Image(uiImage: rendered)
                    ShareLink(item: image, preview: SharePreview(share.month.title, image: image)) {
                        CircleIcon(systemName: "square.and.arrow.up", size: 50, isProminent: true)
                    }
                } else {
                    CircleIcon(systemName: "square.and.arrow.up", size: 50, isProminent: true)
                        .opacity(0.4)
                }
            }
            .accessibilityLabel("共有")
            .accessibilityIdentifier("month-share-link")

            Button("保存", systemImage: "square.and.arrow.down") {
                guard let rendered else { return }
                Task { show(await PhotoSaver.save(rendered)) }
            }
            .buttonStyle(.pill)
            .accessibilityIdentifier("month-share-save")
            Button("コピー", systemImage: "doc.on.doc") {
                guard let rendered else { return }
                UIPasteboard.general.image = rendered
                show("コピーしました")
            }
            .buttonStyle(.pill)
            .accessibilityIdentifier("month-share-copy")
        }
        .disabled(rendered == nil)
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if toast == message { withAnimation { toast = nil } }
        }
    }
}

/// 共有する1か月の画像。紙の上に月の見出しと7列のマスを並べ、登録した日に絵を貼る
struct MonthPoster: View {
    /// 書き出すときの大きさ（pt）。3倍で書き出すので 1080×1350px（縦 4:5）
    static let renderSize = CGSize(width: 360, height: 450)
    /// 1マスに貼る絵の読み込み時の長辺（px）
    static let stickerPixelSize: CGFloat = 300

    let month: MonthGrid
    let images: [DayKey: UIImage]
    let cutouts: Set<DayKey>

    private let paper = Color(red: 0.98, green: 0.975, blue: 0.965)
    private let ink = Color(white: 0.18)

    var body: some View {
        GeometryReader { geometry in
            // 書き出しの大きさを基準に、プレビューでも同じ見た目になるよう全体を比率で決める
            let u = geometry.size.width / Self.renderSize.width
            let cells = month.cells()
            let rows = Int((Double(cells.count) / 7).rounded(.up))

            VStack(alignment: .leading, spacing: 10 * u) {
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text("\(String(month.year))")
                        .font(.system(size: 13 * u, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.5))
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(month.month)月")
                            .font(.system(size: 34 * u, weight: .bold, design: .rounded))
                            .foregroundStyle(ink)
                        Spacer()
                        Text("\(images.count)日分の絵日記")
                            .font(.system(size: 11 * u, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.5))
                    }
                }

                HStack(spacing: 0) {
                    ForEach(Array(month.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 10 * u, weight: .medium, design: .rounded))
                            .foregroundStyle(ink.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                }

                // マスは行数に合わせて縦に伸ばし、5行の月も6行の月も紙いっぱいに収める
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        GridRow {
                            ForEach(0..<7, id: \.self) { column in
                                let index = row * 7 + column
                                cell(index < cells.count ? cells[index] : nil, unit: u)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 22 * u)
            .padding(.top, 24 * u)
            .padding(.bottom, 18 * u)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(paper)
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func cell(_ key: DayKey?, unit u: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if let key {
                    if let image = images[key] {
                        sticker(image, isCutout: cutouts.contains(key), unit: u)
                            .rotationEffect(.degrees(StickerMotion.tilt(for: key) * 1.6))
                    } else {
                        Text("\(key.day)")
                            .font(.system(size: 11 * u, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ink.opacity(0.3))
                    }
                }
            }
    }

    @ViewBuilder
    private func sticker(_ image: UIImage, isCutout: Bool, unit u: CGFloat) -> some View {
        if isCutout {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(2 * u)
                .shadow(color: .black.opacity(0.18), radius: 1.5 * u, y: 1 * u)
        } else {
            Color.white
                .overlay {
                    Image(uiImage: image).resizable().scaledToFill()
                }
                .clipShape(.rect(cornerRadius: 5 * u))
                .aspectRatio(1, contentMode: .fit)
                .padding(3 * u)
                .shadow(color: .black.opacity(0.16), radius: 1.5 * u, y: 1 * u)
        }
    }
}
