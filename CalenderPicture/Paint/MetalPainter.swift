//
//  MetalPainter.swift
//  CalenderPicture
//
//  Core Image で下ごしらえした画像をテクスチャにして Metal の compute カーネルで描き、CIImage に戻す。
//  CPU のビットマップを介してやり取りする。ビットマップもテクスチャも 0 行目が上なので、上下はそのまま対応する
//

import CoreImage
import Metal

nonisolated enum MetalPainter {
    /// カーネルに渡す画像。テクスチャの番号は並べた順（0, 1, …）で、出力はその次の番号
    struct Input {
        enum Kind {
            /// RGBA
            case color
            /// R だけ（マスクなど）
            case gray
        }

        let image: CIImage
        let kind: Kind
    }

    private static let device = MTLCreateSystemDefaultDevice()
    private static let queue = device?.makeCommandQueue()
    private static let library = device?.makeDefaultLibrary()

    /// `function` の名前のカーネルで extent の大きさの絵を描く。出力は乗算済みアルファ。Metal が使えないなどで描けなかったら nil
    static func run<Params>(_ function: String, inputs: [Input], params: Params, extent: CGRect) -> CIImage? {
        guard let device, let queue,
              let function = library?.makeFunction(name: function),
              let pipeline = try? device.makeComputePipelineState(function: function)
        else { return nil }
        let width = Int(extent.width), height = Int(extent.height)
        guard width > 0, height > 0 else { return nil }

        var textures: [MTLTexture] = []
        for input in inputs {
            guard let texture = texture(from: input, width: width, height: height, extent: extent, device: device) else { return nil }
            textures.append(texture)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderWrite]
        guard let output = device.makeTexture(descriptor: descriptor),
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeComputeCommandEncoder()
        else { return nil }

        var params = params
        encoder.setComputePipelineState(pipeline)
        for (index, texture) in textures.enumerated() {
            encoder.setTexture(texture, index: index)
        }
        encoder.setTexture(output, index: textures.count)
        encoder.setBytes(&params, length: MemoryLayout<Params>.stride, index: 0)
        let group = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: group)
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        guard commands.status == .completed else { return nil }

        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        output.getBytes(&pixels, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return CIImage(bitmapData: Data(pixels), bytesPerRow: rowBytes, size: CGSize(width: width, height: height),
                       format: .RGBA8, colorSpace: nil)
    }

    private static func texture(from input: Input, width: Int, height: Int, extent: CGRect, device: MTLDevice) -> MTLTexture? {
        let (format, pixelFormat, bytesPerPixel): (CIFormat, MTLPixelFormat, Int) = switch input.kind {
        case .color: (.RGBA8, .rgba8Unorm, 4)
        case .gray: (.R8, .r8Unorm, 1)
        }
        let rowBytes = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        CrayonFilter.context.render(input.image, toBitmap: &pixels, rowBytes: rowBytes, bounds: extent, format: format, colorSpace: nil)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: rowBytes)
        return texture
    }
}
