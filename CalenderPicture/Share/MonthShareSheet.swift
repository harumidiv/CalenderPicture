//
//  MonthShareSheet.swift
//  CalenderPicture
//
//  1か月ぶんのらくがきを、パステルの紙にばらばらに貼ったコラージュ1枚にして共有する。
//  年月を大きく入れ、キャラクターは白いふちのシールに、紙ごとの絵は白いふちのカードにして紙いっぱいに敷き詰める。
//  「おかわり」を押すたびに、今の並びはそのままで、同じ絵をもう一周ぶん、まだ空いている場所から貼り足す。
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
    /// 並べ方の乱数の種。「シャッフル」で変える
    @State private var seed = UInt64.random(in: .min ... .max)
    /// 「おかわり」で貼り足した段の乱数の種（押した順）
    @State private var extraSeeds: [UInt64] = []
    /// おかわりできる回数（多すぎると書き出しが重くなる）
    private static let maxExtras = 5
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 14) {
            toolbar
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
        }
        .task(id: RenderKey(loaded: images != nil, seed: seed, extraSeeds: extraSeeds)) {
            guard let images else { return }
            let renderer = ImageRenderer(content: poster(images)
                .frame(width: MonthPoster.renderSize.width, height: MonthPoster.renderSize.height))
            renderer.scale = 3
            rendered = renderer.uiImage
        }
    }

    private struct RenderKey: Equatable {
        let loaded: Bool
        let seed: UInt64
        let extraSeeds: [UInt64]
    }

    private func poster(_ images: [DayKey: UIImage]) -> MonthPoster {
        MonthPoster(month: share.month, images: images, cutouts: Set(share.stickers.filter(\.value.isCutout).keys), seed: seed,
                    extraSeeds: extraSeeds)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// プレビューの上の行: 閉じる・並べ方を変える（画像の見出しに重ならないよう、画像の外に置く）
    private var toolbar: some View {
        HStack {
            Button(action: onClose) { CircleIcon(systemName: "xmark", size: 34) }
                .buttonStyle(.plain)
                .accessibilityLabel("閉じる")
                .accessibilityIdentifier("month-share-close")
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.35)) { extraSeeds.append(.random(in: .min ... .max)) }
            } label: {
                Label(extraSeeds.isEmpty ? "おかわり" : "おかわり \(extraSeeds.count)", systemImage: "plus.square.on.square")
                    .contentTransition(.numericText())
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DoodStyle.background, in: .capsule)
            .buttonStyle(.plain)
            .disabled(extraSeeds.count >= Self.maxExtras)
            .opacity(extraSeeds.count >= Self.maxExtras ? 0.4 : 1)
            .accessibilityLabel("同じ絵を上からもう一周貼る")
            .accessibilityValue("\(extraSeeds.count)回")
            .accessibilityIdentifier("month-share-more")
            // シャッフルは、おかわりした回数はそのままで全部の並びを変える
            Button("シャッフル", systemImage: "shuffle") {
                withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
                    seed = .random(in: .min ... .max)
                    extraSeeds = extraSeeds.map { _ in .random(in: .min ... .max) }
                }
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DoodStyle.background, in: .capsule)
            .buttonStyle(.plain)
            .accessibilityLabel("並べ方を変える")
            .accessibilityIdentifier("month-share-shuffle")
        }
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

/// 共有する1か月の画像。パステルの紙の左上に年月を大きく入れ、らくがきを散らして貼る
struct MonthPoster: View {
    /// 書き出すときの大きさ（pt）。3倍で書き出すので 1080×1350px（縦 4:5。X でも Instagram でも切れにくい）
    static let renderSize = CGSize(width: 360, height: 450)
    /// 1枚の絵の読み込み時の長辺（px）
    static let stickerPixelSize: CGFloat = 500

    let month: MonthGrid
    let images: [DayKey: UIImage]
    let cutouts: Set<DayKey>
    let seed: UInt64
    /// おかわりで上から貼り足す段の種（空なら1周だけ）
    var extraSeeds: [UInt64] = []

    private let ink = Color(red: 0.16, green: 0.17, blue: 0.24)
    /// 絵をかぶせない場所: 左上の年月の見出しと、右下の小さな文字
    static let reserved = [CGRect(x: 0, y: 0, width: 170, height: 150), CGRect(x: 250, y: 425, width: 110, height: 25)]

    /// 月ごとの紙の色（季節に合わせたパステル）
    private static let papers: [Color] = [
        Color(red: 0.89, green: 0.93, blue: 0.99),  // 1月
        Color(red: 0.99, green: 0.89, blue: 0.92),  // 2月
        Color(red: 0.99, green: 0.92, blue: 0.94),  // 3月
        Color(red: 0.93, green: 0.97, blue: 0.88),  // 4月
        Color(red: 0.88, green: 0.97, blue: 0.92),  // 5月
        Color(red: 0.90, green: 0.91, blue: 0.99),  // 6月
        Color(red: 0.86, green: 0.95, blue: 0.99),  // 7月
        Color(red: 1.00, green: 0.95, blue: 0.84),  // 8月
        Color(red: 0.96, green: 0.92, blue: 0.99),  // 9月
        Color(red: 1.00, green: 0.91, blue: 0.84),  // 10月
        Color(red: 0.97, green: 0.91, blue: 0.86),  // 11月
        Color(red: 0.91, green: 0.95, blue: 0.93),  // 12月
    ]
    /// 背景に散らす小さな飾りの色（クレヨンの色）
    private static let crayons: [Color] = [
        Color(red: 0.93, green: 0.36, blue: 0.27), Color(red: 0.98, green: 0.74, blue: 0.16),
        Color(red: 0.24, green: 0.48, blue: 0.86), Color(red: 0.36, green: 0.72, blue: 0.42),
        Color(red: 0.95, green: 0.52, blue: 0.70),
    ]
    private static let doodles = ["star.fill", "heart.fill", "sparkle", "circle.fill", "cloud.fill"]

    var body: some View {
        GeometryReader { geometry in
            // 書き出しの大きさを基準に、プレビューでも同じ見た目になるよう全体を比率で決める
            let u = geometry.size.width / Self.renderSize.width
            let size = Self.renderSize
            let keys = images.keys.sorted()
            let paper = CGRect(origin: .zero, size: size).insetBy(dx: 12, dy: 14)
            // 段ごとに同じ絵を1枚ずつ貼る。おかわりの段は、それまでの段で埋まっていない場所から埋める
            let layers = ([seed] + extraSeeds).enumerated().reduce(into: [[(id: String, key: DayKey, placement: CollageLayout.Placement)]]()) { result, layer in
                let below = result.flatMap { $0.map(\.placement) }
                let placements = CollageLayout.place(count: keys.count, in: paper, avoiding: Self.reserved, seed: layer.element, over: below)
                result.append(zip(keys, placements).map { (id: "\(layer.offset)-\($0.string)", key: $0, placement: $1) })
            }

            ZStack(alignment: .topLeading) {
                Self.papers[(month.month - 1) % 12]

                decorations(in: size, unit: u)

                ForEach(layers.flatMap { $0 }, id: \.id) { item in
                    sticker(images[item.key]!, isCutout: cutouts.contains(item.key), size: item.placement.size * u)
                        .rotationEffect(.degrees(item.placement.rotation))
                        .position(x: item.placement.center.x * u, y: item.placement.center.y * u)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                }

                header(unit: u)
                    .padding(.leading, 22 * u)
                    .padding(.top, 20 * u)

                Text("my doodle diary")
                    .font(.system(size: 10 * u, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.45))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16 * u)
                    .padding(.bottom, 12 * u)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .environment(\.colorScheme, .light)
    }

    private func header(unit u: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(month.year))
                .font(.system(size: 16 * u, weight: .heavy, design: .rounded))
                .tracking(2 * u)
            HStack(alignment: .lastTextBaseline, spacing: 2 * u) {
                Text("\(month.month)")
                    .font(.system(size: 88 * u, weight: .black, design: .rounded))
                Text("月")
                    .font(.system(size: 26 * u, weight: .heavy, design: .rounded))
            }
            .padding(.top, -10 * u)
            HStack(spacing: 6 * u) {
                Text(Self.englishMonth(month.month))
                    .font(.system(size: 12 * u, weight: .heavy, design: .rounded))
                    .tracking(3 * u)
                Text("\(images.count) days")
                    .font(.system(size: 10 * u, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7 * u)
                    .padding(.vertical, 3 * u)
                    .background(ink, in: .capsule)
            }
            .padding(.top, -6 * u)
        }
        .foregroundStyle(ink)
    }

    /// 背景の小さな飾り。絵と同じ種から決めるので、シャッフルすると一緒に変わる
    private func decorations(in size: CGSize, unit u: CGFloat) -> some View {
        var random = SplitMix64(state: seed ^ 0xD00D)
        let items = (0..<16).map { _ in
            (symbol: Self.doodles.randomElement(using: &random)!, color: Self.crayons.randomElement(using: &random)!,
             x: CGFloat.random(in: 0...size.width, using: &random), y: CGFloat.random(in: 0...size.height, using: &random),
             size: CGFloat.random(in: 8...18, using: &random), rotation: Double.random(in: -30...30, using: &random))
        }
        return ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            Image(systemName: item.symbol)
                .font(.system(size: item.size * u))
                .foregroundStyle(item.color.opacity(0.55))
                .rotationEffect(.degrees(item.rotation))
                .position(x: item.x * u, y: item.y * u)
        }
    }

    /// 1枚の絵。キャラクターは白いふちどりのシール、紙ごとの絵は白いふちのカードにする
    @ViewBuilder
    private func sticker(_ image: UIImage, isCutout: Bool, size: CGFloat) -> some View {
        let outline = max(2, size * 0.035)
        Group {
            if isCutout {
                ZStack {
                    // 白い形を8方向にずらして重ね、ふちどりにする
                    ForEach(0..<8, id: \.self) { index in
                        let angle = Double(index) / 8 * 2 * .pi
                        Image(uiImage: image)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .offset(x: cos(angle) * outline, y: sin(angle) * outline)
                    }
                    Image(uiImage: image).resizable().scaledToFit()
                }
                // ふちどりを1枚にまとめてから影を付ける（重ねた白いコピーごとに影が出ないように）
                .compositingGroup()
                .shadow(color: .black.opacity(0.18), radius: size * 0.03, y: size * 0.02)
            } else {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.84, height: size * 0.84)
                    .clipShape(.rect(cornerRadius: size * 0.05))
                    .padding(size * 0.05)
                    .background(.white, in: .rect(cornerRadius: size * 0.08))
                    .shadow(color: .black.opacity(0.16), radius: size * 0.04, y: size * 0.025)
            }
        }
        .frame(width: size, height: size)
    }

    private static func englishMonth(_ month: Int) -> String {
        ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
         "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"][(month - 1) % 12]
    }
}
