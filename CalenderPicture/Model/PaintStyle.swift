//
//  PaintStyle.swift
//  CalenderPicture
//
//  写真をどんな絵にするか（塗り方）。アプリの起動時に選び、次に登録する写真から使う。
//  もう無い塗り方が保存されていたら（以前のバージョンで選んだものなど）クレヨンになる。
//

import CoreGraphics
import Foundation

nonisolated enum PaintStyle: String, CaseIterable, Identifiable {
    case crayon
    case cel
    case paperCut
    case pixelArt
    case woodblock
    case popArt

    /// 選んだ塗り方を覚えておく UserDefaults のキー（UI テストでは起動引数 -paintStyle crayon などで指定する）
    static let storageKey = "paintStyle"

    /// まだ選んでいないとき（消した塗り方を選んでいたときも）の塗り方
    static let defaultStyle: PaintStyle = .pixelArt

    /// いま選ばれている塗り方
    static var current: PaintStyle {
        UserDefaults.standard.string(forKey: storageKey).flatMap(PaintStyle.init(rawValue:)) ?? defaultStyle
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crayon: "クレヨン"
        case .cel: "アニメ調"
        case .paperCut: "切り絵"
        case .pixelArt: "ドット絵"
        case .woodblock: "版画"
        case .popArt: "ポップアート"
        }
    }

    var subtitle: String {
        switch self {
        case .crayon: "白い紙にらくがきしたような絵"
        case .cel: "3段の塗りと輪郭線のアニメの1コマ"
        case .paperCut: "色紙を重ねて影を落とした切り絵"
        case .pixelArt: "大きな画素と少ない色のゲーム風"
        case .woodblock: "決まったインクで刷った木版画"
        case .popArt: "網点と太い輪郭のアメコミ風"
        }
    }

    var systemImage: String {
        switch self {
        case .crayon: "scribble.variable"
        case .cel: "face.smiling"
        case .paperCut: "scissors"
        case .pixelArt: "square.grid.3x3.fill"
        case .woodblock: "mountain.2.fill"
        case .popArt: "star.circle.fill"
        }
    }

    /// ShaderPaint.metal で描く塗り方のカーネル名
    private var shaderKernel: String? {
        switch self {
        case .cel: "paintCel"
        case .paperCut: "paintPaperCut"
        case .pixelArt: "paintPixelArt"
        case .woodblock: "paintWoodblock"
        case .popArt: "paintPopArt"
        case .crayon: nil
        }
    }

    /// 下ごしらえ済みの写真をこの塗り方の絵に変換する。描けなかったら nil。
    /// 下ごしらえ（`CrayonFilter.canvas(for:)`）は重いので、同じ写真をいくつもの塗り方で描くときは使い回す
    func paint(_ canvas: CrayonFilter.Canvas) -> CrayonResult? {
        if let shaderKernel { return ShaderPaintFilter.apply(canvas: canvas, kernel: shaderKernel) }
        return CrayonFilter.apply(canvas: canvas)
    }

    /// 写真をこの塗り方の絵に変換する。描けなかったら nil
    func paint(_ cgImage: CGImage) -> CrayonResult? {
        paint(CrayonFilter.canvas(for: cgImage))
    }

    /// 写真をこの塗り方の絵に変換する。描けなかったとき（Metal が使えないなど）はクレヨンで描く
    func apply(to cgImage: CGImage) -> CrayonResult? {
        let canvas = CrayonFilter.canvas(for: cgImage)
        return paint(canvas) ?? CrayonFilter.apply(canvas: canvas)
    }
}
