//
//  PuffyCharacter.swift
//  CalenderPicture（DanceImage から移植）
//
//  切り抜き画像の輪郭を「ふくらませた」立体メッシュを作り、キャラクターの Entity にする。
//  輪郭どおりに表面・裏面（写真）を張り、そのあいだをグレーの側面でふさいだ閉じた立体にする。
//  puffiness を上げると、表面・裏面が輪郭から内側へ離れるほど盛り上がり、ぬいぐるみのような形になる。
//

import CoreGraphics
import RealityKit
import simd
import UIKit

enum PuffyCharacter {
    nonisolated enum BuildError: Error {
        case invalidImage
        /// 不透明な部分がなく、立体にできない
        case emptyShape
    }

    /// メインスレッド外で用意できる、立体の形とテクスチャ。
    struct Prepared: @unchecked Sendable {
        let descriptor: MeshDescriptor
        let texture: CGImage
    }

    /// 重い計算（輪郭・厚み・縁の色）をまとめて行う。メインスレッドを止めないよう、裏のスレッドで呼ぶ。
    nonisolated static func prepare(from image: CGImage, height: Float = 1.0, puffiness: Float = 0) throws -> Prepared {
        // 透明な余白があると足元が浮いて小さくなるので、不透明な範囲に切り詰めてから立体にする
        guard let full = RGBAImage(image) else { throw BuildError.invalidImage }
        guard let bounds = full.opaqueBounds() else { throw BuildError.emptyShape }
        guard let image = image.cropping(to: bounds), let pixels = RGBAImage(image) else { throw BuildError.invalidImage }

        guard let descriptor = descriptor(for: pixels, worldHeight: height, puffiness: puffiness) else {
            throw BuildError.emptyShape
        }
        return Prepared(descriptor: descriptor, texture: bleedEdgeColors(of: pixels) ?? image)
    }

    /// 用意した形とテクスチャを RealityKit に登録して、立体の見た目（メッシュと素材）を作る。
    /// 見た目の切り替えでは、これを body の子として差し替える。
    static func makeModel(from prepared: Prepared) throws -> ModelEntity {
        let mesh = try MeshResource.generate(from: [prepared.descriptor])

        // 素材0: 表裏の写真、素材1: 側面のグレー
        var photo = PhysicallyBasedMaterial()
        let color = try TextureResource(image: prepared.texture, options: .init(semantic: .color))
        photo.baseColor = .init(texture: .init(color))
        photo.roughness = 0.85
        photo.metallic = 0.0
        photo.faceCulling = .none

        var side = PhysicallyBasedMaterial()
        side.baseColor = .init(tint: .init(white: 0.78, alpha: 1))
        side.roughness = 0.9
        side.metallic = 0.0
        side.faceCulling = .none

        return ModelEntity(mesh: mesh, materials: [photo, side])
    }

    /// 足元（下端中央）が原点、高さ `height` の立体の見た目を作る（準備と登録をまとめて行う）。
    static func makeModel(from image: CGImage, height: Float = 1.0, puffiness: Float = 0) throws -> ModelEntity {
        try makeModel(from: prepare(from: image, height: height, puffiness: puffiness))
    }

    /// 足元（下端中央）が原点、高さ `height` のキャラクターを作る。
    /// 階層: root（位置・向き）> body（跳ねる・揺れる）> model
    /// - Parameter puffiness: 表裏のふくらみの強さ。0 で平らな板（写真の形を押し出しただけ）、1 でぬいぐるみ風。
    static func make(from image: CGImage, height: Float = 1.0, puffiness: Float = 0) throws -> Entity {
        let body = Entity()
        body.name = "body"
        body.addChild(try makeModel(from: image, height: height, puffiness: puffiness))

        let root = Entity()
        root.addChild(body)
        return root
    }

    /// 輪郭上・グリッド上の点。`g` はグリッド座標（i, j）。
    nonisolated private struct Point {
        var g: SIMD2<Float>
        var puff: Float
        var normal: SIMD3<Float>
        var onContour: Bool
    }

    /// 不透明な部分がなければ nil。
    nonisolated private static func descriptor(for pixels: RGBAImage, worldHeight: Float, puffiness: Float) -> MeshDescriptor? {
        // グリッドの細かさ（長辺のセル数）
        let resolution = 128
        let aspect = Float(pixels.width) / Float(pixels.height)
        let gx = pixels.width >= pixels.height ? resolution : max(2, Int(Float(resolution) * aspect))
        let gy = pixels.width >= pixels.height ? max(2, Int(Float(resolution) / aspect)) : resolution
        let vx = gx + 1, vy = gy + 1
        let worldWidth = worldHeight * aspect
        let cell = worldWidth / Float(gx)
        // 側面の厚み（表と裏の縁の間隔の半分）
        let edgeHalfThickness = worldHeight * 0.04

        func index(_ i: Int, _ j: Int) -> Int { j * vx + i }

        // 頂点ごとの「内側らしさ」（>0 が内側）。周囲のアルファを平均して輪郭をなめらかにする。
        // グリッドの外周は必ず外側にして、輪郭が閉じるようにする。
        let sampleRadius = max(1, Int(Float(pixels.width) / Float(gx) * 0.5))
        var field = [Float](repeating: -0.5, count: vx * vy)
        for j in 1..<(vy - 1) {
            for i in 1..<(vx - 1) {
                let cx = Int(Float(i) / Float(gx) * Float(pixels.width - 1))
                let cy = Int(Float(j) / Float(gy) * Float(pixels.height - 1))
                var sum = 0, count = 0
                for y in max(0, cy - sampleRadius)...min(pixels.height - 1, cy + sampleRadius) {
                    for x in max(0, cx - sampleRadius)...min(pixels.width - 1, cx + sampleRadius) {
                        sum += Int(pixels.alpha(x, y))
                        count += 1
                    }
                }
                field[index(i, j)] = Float(sum) / Float(count * 255) - 0.5
            }
        }
        let inside = field.map { $0 > 0 }

        // 輪郭からの距離（2パスのチャンファー距離変換）
        let far = Float.greatestFiniteMagnitude
        var distance = inside.map { $0 ? far : 0 }
        func value(_ i: Int, _ j: Int) -> Float {
            (i < 0 || j < 0 || i >= vx || j >= vy) ? 0 : distance[index(i, j)]
        }
        let diagonal: Float = 1.4142
        for j in 0..<vy {
            for i in 0..<vx where inside[index(i, j)] {
                distance[index(i, j)] = min(distance[index(i, j)],
                                            value(i - 1, j) + 1, value(i, j - 1) + 1,
                                            value(i - 1, j - 1) + diagonal, value(i + 1, j - 1) + diagonal)
            }
        }
        for j in stride(from: vy - 1, through: 0, by: -1) {
            for i in stride(from: vx - 1, through: 0, by: -1) where inside[index(i, j)] {
                distance[index(i, j)] = min(distance[index(i, j)],
                                            value(i + 1, j) + 1, value(i, j + 1) + 1,
                                            value(i + 1, j + 1) + diagonal, value(i - 1, j + 1) + diagonal)
            }
        }

        // 距離を円弧状の盛り上がりに変換（輪郭で 0、中央はなだらか）
        let maxDistance = (distance.max() ?? 1) * cell
        let radius = max(cell, min(maxDistance, worldHeight * 0.18))
        var puff: [Float] = distance.map { d in
            let t = min(max(d - 0.5, 0) * cell / radius, 1)
            return puffiness * radius * 0.6 * (1 - (1 - t) * (1 - t)).squareRoot()
        }
        // グリッド状の段差をならす
        for _ in 0..<2 {
            var smoothed = puff
            for j in 0..<vy {
                for i in 0..<vx where inside[index(i, j)] {
                    var sum: Float = 0
                    var count: Float = 0
                    for dj in -1...1 {
                        for di in -1...1 {
                            let ni = i + di, nj = j + dj
                            guard ni >= 0, nj >= 0, ni < vx, nj < vy else { continue }
                            sum += puff[index(ni, nj)]
                            count += 1
                        }
                    }
                    smoothed[index(i, j)] = sum / count
                }
            }
            puff = smoothed
        }
        func h(_ i: Int, _ j: Int) -> Float {
            puff[index(min(max(i, 0), vx - 1), min(max(j, 0), vy - 1))]
        }

        // 表面の法線（盛り上がりの傾きから）。画像の下方向(j+)はワールドの -y。
        var gridNormals = [SIMD3<Float>](repeating: [0, 0, 1], count: vx * vy)
        for j in 0..<vy {
            for i in 0..<vx {
                let dhdx = (h(i + 1, j) - h(i - 1, j)) / (2 * cell)
                let dhdy = -(h(i, j + 1) - h(i, j - 1)) / (2 * cell)
                gridNormals[index(i, j)] = simd_normalize(SIMD3<Float>(-dhdx, -dhdy, 1))
            }
        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        // 三角形ごとの素材番号（0: 写真, 1: 側面）
        var faceMaterials: [UInt32] = []

        func world(_ g: SIMD2<Float>) -> SIMD2<Float> {
            [(g.x / Float(gx) - 0.5) * worldWidth, (1 - g.y / Float(gy)) * worldHeight]
        }
        func emit(_ g: SIMD2<Float>, z: Float, normal: SIMD3<Float>) -> UInt32 {
            let w = world(g)
            positions.append([w.x, w.y, z])
            normals.append(normal)
            uvs.append([g.x / Float(gx), 1 - g.y / Float(gy)])
            return UInt32(positions.count - 1)
        }
        func corner(_ i: Int, _ j: Int) -> Point {
            Point(g: [Float(i), Float(j)], puff: h(i, j), normal: gridNormals[index(i, j)], onContour: false)
        }

        // マーチングスクエア: 各セルの内側部分を多角形にして表裏に張り、輪郭の線分には側面を張る
        for j in 0..<gy {
            for i in 0..<gx {
                let cornerIndices = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
                guard cornerIndices.contains(where: { inside[index($0.0, $0.1)] }) else { continue }

                var polygon: [Point] = []
                for k in 0..<4 {
                    let (ai, aj) = cornerIndices[k]
                    let (bi, bj) = cornerIndices[(k + 1) % 4]
                    let a = index(ai, aj), b = index(bi, bj)
                    if inside[a] { polygon.append(corner(ai, aj)) }
                    if inside[a] != inside[b] {
                        let t = field[a] / (field[a] - field[b])
                        let pa = corner(ai, aj), pb = corner(bi, bj)
                        polygon.append(Point(
                            g: pa.g + (pb.g - pa.g) * t,
                            puff: 0,
                            normal: simd_normalize(pa.normal + (pb.normal - pa.normal) * t),
                            onContour: true
                        ))
                    }
                }
                guard polygon.count >= 3 else { continue }

                let front = polygon.map { emit($0.g, z: edgeHalfThickness + $0.puff, normal: $0.normal) }
                let back = polygon.map {
                    emit($0.g, z: -(edgeHalfThickness + $0.puff), normal: [$0.normal.x, $0.normal.y, -$0.normal.z])
                }
                for k in 1..<(polygon.count - 1) {
                    indices += [front[0], front[k + 1], front[k]]
                    indices += [back[0], back[k], back[k + 1]]
                    faceMaterials += [0, 0]
                }

                // 側面: 連続する輪郭上の2点を結ぶ線分
                let centroid = polygon.reduce(SIMD2<Float>.zero) { $0 + world($1.g) } / Float(polygon.count)
                for k in 0..<polygon.count {
                    let p = polygon[k], q = polygon[(k + 1) % polygon.count]
                    guard p.onContour, q.onContour else { continue }
                    let wp = world(p.g), wq = world(q.g)
                    let direction = wq - wp
                    guard simd_length(direction) > 1e-6 else { continue }
                    var outward = simd_normalize(SIMD2<Float>(direction.y, -direction.x))
                    if simd_dot(outward, (wp + wq) / 2 - centroid) < 0 { outward = -outward }
                    // 上下の縁で法線を少し傾け、角が丸く見えるようにする
                    let top = simd_normalize(SIMD3<Float>(outward.x, outward.y, 0.5))
                    let bottom = simd_normalize(SIMD3<Float>(outward.x, outward.y, -0.5))
                    let v0 = emit(p.g, z: edgeHalfThickness, normal: top)
                    let v1 = emit(q.g, z: edgeHalfThickness, normal: top)
                    let v2 = emit(q.g, z: -edgeHalfThickness, normal: bottom)
                    let v3 = emit(p.g, z: -edgeHalfThickness, normal: bottom)
                    indices += [v0, v1, v2, v0, v2, v3]
                    faceMaterials += [1, 1]
                }
            }
        }

        guard !indices.isEmpty else { return nil }

        var descriptor = MeshDescriptor(name: "puffy")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        descriptor.primitives = .triangles(indices)
        descriptor.materials = .perFace(faceMaterials)
        return descriptor
    }

    /// 輪郭ぎりぎりで透明部分の色（黒など）を拾わないよう、
    /// 被写体の縁の色を外側へ数ピクセルにじませた不透明画像を作る。
    nonisolated private static func bleedEdgeColors(of pixels: RGBAImage) -> CGImage? {
        let width = pixels.width, height = pixels.height
        var rgb = [Float](repeating: 0, count: width * height * 3)
        var known = [Bool](repeating: false, count: width * height)
        for p in 0..<(width * height) {
            let a = Float(pixels.pixels[p * 4 + 3])
            guard a >= 128 else { continue }
            // 乗算済みアルファを元に戻す
            for c in 0..<3 { rgb[p * 3 + c] = Float(pixels.pixels[p * 4 + c]) * 255 / a }
            known[p] = true
        }
        // 縁の外側の数ピクセルだけを、内側から1ピクセルずつ広げて塗る（画像全体を何度もなめない）
        func neighbors(_ p: Int) -> [Int] {
            let x = p % width, y = p / width
            var result: [Int] = []
            result.reserveCapacity(4)
            if x > 0 { result.append(p - 1) }
            if x < width - 1 { result.append(p + 1) }
            if y > 0 { result.append(p - width) }
            if y < height - 1 { result.append(p + width) }
            return result
        }
        var queued = known
        var frontier: [Int] = []
        for p in 0..<(width * height) where known[p] {
            // 内側の画素のうち、まだ塗られていない画素と接するものだけが出発点
            let x = p % width, y = p / width
            let touchesUnknown = (x > 0 && !known[p - 1]) || (x < width - 1 && !known[p + 1])
                || (y > 0 && !known[p - width]) || (y < height - 1 && !known[p + width])
            guard touchesUnknown else { continue }
            for n in neighbors(p) where !queued[n] {
                queued[n] = true
                frontier.append(n)
            }
        }
        for _ in 0..<6 where !frontier.isEmpty {
            // 1周分はまとめて計算してから確定する（同じ周の画素どうしは参照しない）
            var colors: [SIMD3<Float>] = []
            colors.reserveCapacity(frontier.count)
            for p in frontier {
                var sum = SIMD3<Float>.zero
                var count: Float = 0
                for n in neighbors(p) where known[n] {
                    sum += SIMD3(rgb[n * 3], rgb[n * 3 + 1], rgb[n * 3 + 2])
                    count += 1
                }
                colors.append(sum / max(count, 1))
            }
            var next: [Int] = []
            for (i, p) in frontier.enumerated() {
                rgb[p * 3] = colors[i].x
                rgb[p * 3 + 1] = colors[i].y
                rgb[p * 3 + 2] = colors[i].z
                known[p] = true
            }
            for p in frontier {
                for n in neighbors(p) where !queued[n] {
                    queued[n] = true
                    next.append(n)
                }
            }
            frontier = next
        }

        var data = [UInt8](repeating: 255, count: width * height * 4)
        for p in 0..<(width * height) {
            for c in 0..<3 { data[p * 4 + c] = UInt8(min(255, rgb[p * 3 + c])) }
        }
        return data.withUnsafeMutableBytes { raw in
            CGContext(
                data: raw.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )?.makeImage()
        }
    }
}
