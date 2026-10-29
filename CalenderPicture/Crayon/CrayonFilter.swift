//
//  CrayonFilter.swift
//  CalenderPicture（ImageTransrator から移植）
//

import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// クレヨン変換の結果
nonisolated struct CrayonResult {
    /// 紙の背景つきのクレヨン画
    let drawing: CGImage
    /// 背景が透明なクレヨンのキャラクター（3D 表示用）。主役を切り抜けなかったときは nil
    let character: CGImage?
    /// 元写真を主役の形に切り抜いた画像（3D 表示の「写真」用）。主役を切り抜けなかったときは nil
    let photoCutout: CGImage?
}

/// 写真の主役（人・物）を切り抜き、白い紙にクレヨンでらくがきしたような絵に変換する。
/// 主役の切り抜きなどの下ごしらえ（`canvas(for:)`）は、ほかの塗り方でも使う
nonisolated enum CrayonFilter {
    // しきい値を直感的に扱えるよう、ガンマ空間のまま処理する
    static let context = CIContext(options: [.workingColorSpace: NSNull()])
    static let paperColor = CIColor(red: 0.98, green: 0.975, blue: 0.965)
    private static let outputLongSide: CGFloat = 1200

    /// 主役を中心にしたキャンバスへ写真を置いたもの（どの塗り方でも共通の下ごしらえ）
    struct Canvas {
        let source: CIImage
        /// 元写真の座標での主役のマスク。切り抜けなかったとき（顕著性や四角で代用したとき）は nil
        let foreground: CIImage?
        /// 元写真の座標での主役を囲む矩形
        let box: CGRect
        /// キャンバスに置いた写真（顔のぼかし・明るさの補正済み）
        let image: CIImage
        /// キャンバスの座標での主役のマスク（主役 = 白）
        let mask: CIImage
        /// キャンバスの座標での主役を囲む矩形
        let subjectBox: CGRect
        let extent: CGRect
        /// 解像度に依存しないための基準
        let unit: CGFloat

        /// 元写真を主役の形に切り抜いたもの（Apple の切り抜きの輪郭そのまま）
        var photoCutout: CGImage? {
            foreground.flatMap { mask in
                let cutout = source.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: CIImage.clear,
                    kCIInputMaskImageKey: mask,
                ])
                return context.createCGImage(cutout.cropped(to: box), from: box)
            }
        }
    }

    static func canvas(for cgImage: CGImage) -> Canvas {
        let source = CIImage(cgImage: cgImage)
        let sourceExtent = source.extent

        // 1. 主役を切り抜く。切り抜けない写真（風景・料理など）は目を引く部分をぼんやり丸く使い、
        //    それも見つからなければ写真全体を少し内側に寄せた四角で使う
        let foreground = foregroundMask(in: cgImage, extent: sourceExtent)
        let subjectMask = foreground
            ?? saliencyMask(in: cgImage, extent: sourceExtent)
            ?? CIImage(color: .white).cropped(to: sourceExtent.insetBy(dx: sourceExtent.width * 0.04, dy: sourceExtent.height * 0.04))
        let box = boundingBox(of: subjectMask, extent: sourceExtent) ?? sourceExtent

        // 2. 主役の周りに余白を取ったキャンバスを作り、長辺 outputLongSide に揃える
        let margin = max(box.width, box.height) * 0.15
        let canvasBox = box.insetBy(dx: -margin, dy: -margin)
        let scale = outputLongSide / max(canvasBox.width, canvasBox.height)
        let toCanvas = CGAffineTransform(translationX: -canvasBox.minX, y: -canvasBox.minY)
            .concatenating(.init(scaleX: scale, y: scale))
        let extent = CGRect(x: 0, y: 0, width: canvasBox.width * scale, height: canvasBox.height * scale).integral

        var image = source.clampedToExtent().transformed(by: toCanvas)
        // 写真の外側は主役なし（写真の端で切れた主役はそこで途切れる）
        let mask = subjectMask.composited(over: CIImage(color: .black)).transformed(by: toCanvas)
        let faces = detectFaces(in: cgImage, extent: sourceExtent).map { $0.applying(toCanvas) }

        // 顔の中だけ強くぼかし、目鼻口などの小さなパーツを消す（髪や陰影などの大きな形は残る）
        image = softenFaces(faces, in: image)

        // 暗い写真は、主役の中間の明るさだけを持ち上げる（黒と白の点や色味は変えない）
        let subjectBox = box.applying(toCanvas)
        image = brightened(image, mask: mask, in: subjectBox)

        return Canvas(source: source, foreground: foreground, box: box, image: image, mask: mask,
                      subjectBox: subjectBox, extent: extent, unit: outputLongSide / 1000)
    }

    static func apply(to cgImage: CGImage) -> CrayonResult? {
        apply(canvas: canvas(for: cgImage))
    }

    static func apply(canvas: Canvas) -> CrayonResult? {
        let (image, mask, subjectBox, extent, unit) = (canvas.image, canvas.mask, canvas.subjectBox, canvas.extent, canvas.unit)

        // 3. 主役の色だけでパレットを作り、大胆に減色して数色の塊にする
        let palette = makePalette(from: image, mask: mask, in: subjectBox)
        let detail: CGFloat = 70  // 主役を何 px まで縮めて単純化するか。小さいほど大胆
        var flat = simplified(image, palette: palette, scale: detail / max(subjectBox.width, subjectBox.height), unit: unit)

        // 塗りの境界をガタつかせて手塗り感を出す
        let wobble = noise(seed: 0, extent: extent)
            .transformed(by: .init(scaleX: 8 * unit, y: 8 * unit))
            .applyingGaussianBlur(sigma: 5 * unit)
        flat = flat.applyingFilter("CIDisplacementDistortion", parameters: [
            "inputDisplacementImage": wobble,
            kCIInputScaleKey: 6 * unit,
        ])

        // 4. パステルの質感 = 紙の凹凸（細かい粒）+ いろいろな向きの短いストローク
        let grain = crayonGrain(extent: extent, unit: unit)

        // シルエットも単純化し、縁を粒でガサガサにする
        let softMask = mask
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: detail / max(subjectBox.width, subjectBox.height)])
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 0.8)
            .transformed(by: .init(scaleX: max(subjectBox.width, subjectBox.height) / detail,
                                   y: max(subjectBox.width, subjectBox.height) / detail))
            .applyingGaussianBlur(sigma: 4 * unit)
            .applyingFilter("CIDisplacementDistortion", parameters: [
                "inputDisplacementImage": wobble,
                kCIInputScaleKey: 6 * unit,
            ])
        let roughMask = gain(
            gain(grain, k: -1, bias: 1).applyingFilter("CIMix", parameters: [
                kCIInputBackgroundImageKey: softMask,
                kCIInputAmountKey: 0.35,
            ]),
            k: 8, bias: -3.6)

        // 塗りに濃淡をつけ、粒の明るい部分は紙の色を見せる
        let paper = CIImage(color: paperColor)
        let shade = gain(grain, k: -0.3, bias: 1.1)
        var drawing = shade.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: flat])
        drawing = paper.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: drawing,
            kCIInputMaskImageKey: gain(grain, k: 4, bias: -2.9),
        ])

        // 5. 紙の上に主役だけを置く
        let result = drawing.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: paper,
            kCIInputMaskImageKey: roughMask,
        ])
        guard let drawingImage = context.createCGImage(result.cropped(to: extent), from: extent) else { return nil }

        // 6. 3D 用に、紙の代わりに透明を敷いた主役だけの絵も作る（切り抜けたときだけ）
        let character = canvas.foreground.flatMap { _ in
            let cutout = drawing.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.clear,
                kCIInputMaskImageKey: roughMask,
            ])
            return context.createCGImage(cutout.cropped(to: extent), from: extent)
        }
        return CrayonResult(drawing: drawingImage, character: character, photoCutout: canvas.photoCutout)
    }

    // MARK: - 切り抜き・検出

    /// 主役（人・ペット・物）を切り抜ける写真か
    static func hasSubject(in cgImage: CGImage) -> Bool {
        let request = VNGenerateForegroundInstanceMaskRequest()
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        return !(request.results?.first?.allInstances.isEmpty ?? true)
    }

    /// 主役（前景の人・物）のマスク（主役 = 白）
    private static func foregroundMask(in cgImage: CGImage, extent: CGRect) -> CIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
        guard let result = request.results?.first,
              let buffer = try? result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        else { return nil }
        let mask = CIImage(cvPixelBuffer: buffer)
        return mask
            .transformed(by: .init(scaleX: extent.width / mask.extent.width, y: extent.height / mask.extent.height))
            .cropped(to: extent)
    }

    /// 目を引く部分のマスク（主役 = 白）。Vision の顕著性マップ（68×68 程度の粗い熱マップ）を
    /// 写真の大きさに広げ、いちばん目立つ所を基準にしきい値をとる。目立つ物が見つからなければ nil
    private static func saliencyMask(in cgImage: CGImage, extent: CGRect) -> CIImage? {
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        guard let observation = request.results?.first, !(observation.salientObjects ?? []).isEmpty else { return nil }
        return saliencyMask(fromHeatMap: CIImage(cvPixelBuffer: observation.pixelBuffer), extent: extent)
    }

    /// 顕著性の熱マップ（目立つほど明るい）を extent の大きさのマスクにする。目立つ所がなければ nil
    static func saliencyMask(fromHeatMap heat: CIImage, extent: CGRect) -> CIImage? {
        let peak = maximum(of: heat)
        guard peak > 0.01 else { return nil }
        let spread = heat
            .transformed(by: .init(scaleX: extent.width / heat.extent.width, y: extent.height / heat.extent.height))
            .clampedToExtent()
            // 熱マップの升目が見えないよう、ぼかして丸い形にする
            .applyingGaussianBlur(sigma: max(extent.width, extent.height) * 0.03)
        // いちばん目立つ所の 30〜55% の明るさを境目にする
        let mask = gain(spread, k: 1 / (0.25 * peak), bias: -0.3 / 0.25).cropped(to: extent)
        return boundingBox(of: mask, extent: extent) == nil ? nil : mask
    }

    /// 画像のいちばん明るい値（R）
    private static func maximum(of image: CIImage) -> CGFloat {
        let maximum = image.applyingFilter("CIAreaMaximum", parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)])
        var pixel = [Float](repeating: 0, count: 4)
        context.render(maximum, toBitmap: &pixel, rowBytes: 16, bounds: maximum.extent, format: .RGBAf, colorSpace: nil)
        return CGFloat(pixel[0])
    }

    /// マスクの白い部分を囲む矩形
    private static func boundingBox(of mask: CIImage, extent: CGRect) -> CGRect? {
        let size = 128
        let s = CGFloat(size) / max(extent.width, extent.height)
        let w = Int(extent.width * s), h = Int(extent.height * s)
        var pixels = [UInt8](repeating: 0, count: w * h)
        context.render(mask.transformed(by: .init(scaleX: s, y: s)), toBitmap: &pixels, rowBytes: w,
                       bounds: CGRect(x: 0, y: 0, width: w, height: h), format: .L8, colorSpace: nil)
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            for x in 0..<w where pixels[y * w + x] > 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        // ビットマップは上が 0 行目、Core Image は下が原点なので反転する
        return CGRect(x: CGFloat(minX) / s, y: CGFloat(h - 1 - maxY) / s,
                      width: CGFloat(maxX - minX + 1) / s, height: CGFloat(maxY - minY + 1) / s)
    }

    /// 顔の矩形（Core Image 座標）
    private static func detectFaces(in cgImage: CGImage, extent: CGRect) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        // Vision の座標は左下原点の正規化座標なので Core Image とそのまま対応する
        return (request.results ?? []).map {
            VNImageRectForNormalizedRect($0.boundingBox, Int(extent.width), Int(extent.height))
        }
    }

    // MARK: - 明るさ

    /// 主役の平均の明るさをこの値に近づける（0〜1、ガンマ空間）
    static let targetLuma: CGFloat = 0.56
    /// 持ち上げすぎて写真の印象が変わらないよう、ガンマの指数はこれより小さくしない
    static let minimumPower: CGFloat = 0.6

    /// 平均の明るさ `luma` を `targetLuma` へ持ち上げるガンマの指数（1 なら変えない）。明るい写真は暗くしない
    static func brighteningPower(forLuma luma: CGFloat) -> CGFloat {
        guard luma > 0.001, luma < targetLuma else { return 1 }
        return max(log(targetLuma) / log(luma), minimumPower)
    }

    /// 主役の部分の平均の明るさに合わせて、ガンマで中間調を持ち上げる
    private static func brightened(_ image: CIImage, mask: CIImage, in box: CGRect) -> CIImage {
        let masked = image.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage(color: .black),
            kCIInputMaskImageKey: mask,
        ])
        let color = average(of: masked, in: box)
        let coverage = average(of: mask, in: box)[0]
        guard coverage > 0.01 else { return image }
        let luma = (0.299 * color[0] + 0.587 * color[1] + 0.114 * color[2]) / coverage
        let power = brighteningPower(forLuma: luma)
        guard power < 1 else { return image }
        return image.applyingFilter("CIGammaAdjust", parameters: ["inputPower": power])
    }

    /// 範囲内の平均色（RGB, 0〜1）
    private static func average(of image: CIImage, in box: CGRect) -> [CGFloat] {
        let average = image.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: box)])
        var pixel = [Float](repeating: 0, count: 4)
        context.render(average, toBitmap: &pixel, rowBytes: 16, bounds: average.extent,
                       format: .RGBAf, colorSpace: nil)
        return pixel.prefix(3).map { CGFloat($0) }
    }

    // MARK: - 単純化

    /// 主役の部分から代表色を k-means で抽出し、彩度を上げたパレットを作る（暗い色は少し持ち上げる）
    static func makePalette(from image: CIImage, mask: CIImage, in box: CGRect, count: Int = 6) -> CIImage {
        let s = 100 / max(box.width, box.height)
        let subject = image
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: CIImage.clear,
                kCIInputMaskImageKey: mask,
            ])
            .cropped(to: box)
            .transformed(by: .init(scaleX: s, y: s))
        return subject
            .applyingFilter("CIKMeans", parameters: [
                kCIInputExtentKey: CIVector(cgRect: subject.extent),
                "inputCount": count,
                "inputPasses": 30,
                "inputPerceptual": false,
            ])
            // アルファには各色の出現割合が入っているので 1 に戻す
            .settingAlphaOne(in: CGRect(x: 0, y: 0, width: count, height: 1))
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.5])
            // クレヨンは真っ黒にはならないので、暗い色ほど少し持ち上げる（明るい色はほぼそのまま）
            .applyingFilter("CIToneCurve", parameters: [
                "inputPoint0": CIVector(x: 0, y: 0.1),
                "inputPoint1": CIVector(x: 0.25, y: 0.33),
                "inputPoint2": CIVector(x: 0.5, y: 0.57),
                "inputPoint3": CIVector(x: 0.75, y: 0.79),
                "inputPoint4": CIVector(x: 1, y: 1),
            ])
    }

    /// scale 倍に縮小して細部を捨て、パレットの色で塗り分けてから滑らかに戻す
    private static func simplified(_ image: CIImage, palette: CIImage, scale: CGFloat, unit: CGFloat) -> CIImage {
        let palettize = { (input: CIImage) in
            input.applyingFilter("CIPalettize", parameters: [
                "inputPaletteImage": palette,
                "inputPerceptual": false,
            ])
        }
        let small = image.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale])
        // 縮小したまま減色し、ドット状のまま拡大（ぼかしてから減色すると境界に中間色の縞が出るため）
        let blocky = palettize(small.clampedToExtent().applyingGaussianBlur(sigma: 0.8))
            .samplingNearest()
            .transformed(by: .init(scaleX: 1 / scale, y: 1 / scale))
        // ぼかして再度減色し、カクカクした境界を滑らかな曲線にする
        let smooth = palettize(blocky.applyingGaussianBlur(sigma: 0.5 / scale))
        return palettize(smooth.applyingGaussianBlur(sigma: 8 * unit))
    }

    /// 顔の楕円領域を強くぼかし、肌の平均色に少し寄せる（パーツの影が暗い穴として残らないように）
    private static func softenFaces(_ faces: [CGRect], in image: CIImage) -> CIImage {
        var result = image
        for box in faces {
            // 鼻〜頬の帯から肌色を取る
            let sample = CGRect(x: box.minX + box.width * 0.2, y: box.minY + box.height * 0.3,
                                width: box.width * 0.6, height: box.height * 0.25)
            let skin = image
                .applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: sample)])
                .clampedToExtent()
            let blurred = image.applyingGaussianBlur(sigma: box.width * 0.12)
                .applyingFilter("CIMix", parameters: [
                    kCIInputBackgroundImageKey: skin,
                    kCIInputAmountKey: 0.5,
                ])

            // 顔枠の内側ほど強くぼかす楕円マスク
            let mask = CIFilter.radialGradient()
            mask.center = .zero
            mask.radius0 = 0.6
            mask.radius1 = 1
            mask.color0 = .white
            mask.color1 = .black
            let ellipse = mask.outputImage!
                .transformed(by: CGAffineTransform(scaleX: box.width * 0.6, y: box.height * 0.65)
                    .concatenating(.init(translationX: box.midX, y: box.midY)))

            result = blurred.applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: result,
                kCIInputMaskImageKey: ellipse,
            ])
        }
        return result
    }

    // MARK: - テクスチャ

    /// クレヨンの質感（平均 0.5 付近のグレー）。明るいほどクレヨンが乗らない
    private static func crayonGrain(extent: CGRect, unit: CGFloat) -> CIImage {
        let tooth = gain(
            noise(seed: 3, extent: extent)
                .transformed(by: .init(scaleX: 1.1 * unit, y: 1.1 * unit))
                .applyingGaussianBlur(sigma: 0.5 * unit),
            k: 3, bias: -1)
        // 塗る向きを場所ごとに変える（大きなまだら模様で 2 方向を切り替え）
        let region = gain(
            noise(seed: 4, extent: extent)
                .transformed(by: .init(scaleX: 40 * unit, y: 40 * unit))
                .applyingGaussianBlur(sigma: 20 * unit),
            k: 6, bias: -2.5)
        let strokes = streaks(seed: 1, angle: .pi / 3, unit: unit, extent: extent)
            .applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: streaks(seed: 2, angle: -.pi / 5, unit: unit, extent: extent),
                kCIInputMaskImageKey: region,
            ])
        return strokes.applyingFilter("CIMix", parameters: [
            kCIInputBackgroundImageKey: tooth,
            kCIInputAmountKey: 0.5,
        ])
    }

    /// グレースケールの一様ノイズ
    private static func noise(seed: CGFloat, extent: CGRect) -> CIImage {
        // 乱数画像はアルファもランダムなので 1 に固定してから使う
        let random = CIFilter.randomGenerator().outputImage!
            .transformed(by: .init(translationX: seed * 1000, y: seed * 777))
            .settingAlphaOne(in: extent)
            .clampedToExtent()
        return random.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        ])
    }

    /// ノイズを一方向にブラーしてストローク状のテクスチャを作る（平均0.5付近、コントラスト強調済み）
    private static func streaks(seed: CGFloat, angle: CGFloat, unit: CGFloat, extent: CGRect) -> CIImage {
        let s = 1.5 * unit
        let streak = noise(seed: seed, extent: extent)
            .transformed(by: .init(scaleX: s, y: s))
            .applyingFilter("CIMotionBlur", parameters: [
                kCIInputRadiusKey: 5 * unit,
                kCIInputAngleKey: angle,
            ])
        return gain(streak, k: 4, bias: 0.5 - 0.5 * 4)
    }

    /// RGB に対して v * k + bias を適用（結果は 0〜1 にクランプ）
    private static func gain(_ image: CIImage, k: CGFloat, bias: CGFloat) -> CIImage {
        image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: k, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: k, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: k, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: bias, y: bias, z: bias, w: 0),
        ])
        .applyingFilter("CIColorClamp")
    }
}
