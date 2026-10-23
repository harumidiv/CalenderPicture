//
//  WanderView.swift
//  CalenderPicture
//
//  その月のキャラクター（被写体を切り抜けた日のクレヨン画）が、同じ 3D 空間を一斉に動き回る。
//

import RealityKit
import SwiftData
import SwiftUI
import UIKit

struct WanderView: View {
    let month: MonthGrid
    var onClose: () -> Void

    @Query private var entries: [DiaryEntry]
    @State private var stage = WanderStage()

    var body: some View {
        // 削除済みのモデルを非同期処理から触らないよう、値を取り出しておく
        let cast = WanderCast.characters(in: month, from: entries.map { (key: $0.key, character: $0.characterData) })

        ZStack {
            RealityView { content in
                stage.setUp(in: content)
            }
            .ignoresSafeArea()
            .accessibilityIdentifier("wander-stage")

            VStack {
                HStack {
                    Text(month.title)
                        .font(.title3.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: .capsule)
                    Spacer()
                    Button("閉じる", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .padding(10)
                        .background(.regularMaterial, in: .circle)
                        .accessibilityIdentifier("wander-close")
                }
                Spacer()
                if cast.isEmpty {
                    Text("この月は動き回れるキャラクターがいません\n（被写体を切り抜けた写真だけが動きます）")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                        .accessibilityIdentifier("wander-empty")
                }
            }
            .padding()
        }
        .task {
            await stage.show(cast.map(\.character))
        }
    }
}

/// キャラクターが動き回る 3D 空間（床・空・ライト・カメラ）。DanceImage の試作から移植。
@MainActor
final class WanderStage {
    private let characters = Entity()

    func setUp(in content: RealityViewCameraContent) {
        let floor = ModelEntity(
            mesh: .generatePlane(width: 7, depth: 7, cornerRadius: 3.5),
            materials: [SimpleMaterial(color: UIColor(red: 0.85, green: 0.93, blue: 0.82, alpha: 1), roughness: 1, isMetallic: false)]
        )
        content.add(floor)
        content.add(characters)

        // 空: 内側から見える大きな球
        var skyMaterial = UnlitMaterial(color: UIColor(red: 0.66, green: 0.84, blue: 0.97, alpha: 1))
        skyMaterial.faceCulling = .front
        content.add(ModelEntity(mesh: .generateSphere(radius: 40), materials: [skyMaterial]))

        let sun = DirectionalLight()
        sun.light.intensity = 1800
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 12, depthBias: 2)
        sun.look(at: .zero, from: [2, 6, 4], relativeTo: nil)
        content.add(sun)

        // 裏側が真っ黒にならないよう反対側からの補助光
        let fill = DirectionalLight()
        fill.light.intensity = 700
        fill.look(at: .zero, from: [-3, 4, -4], relativeTo: nil)
        content.add(fill)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 50
        camera.look(at: [0, 0.4, 0], from: [0, 2.6, 5.2], relativeTo: nil)
        content.add(camera)
    }

    /// キャラクター画像（PNG）から立体を作り、1体ずつ登場させる。
    func show(_ characterImages: [Data]) async {
        // 人数が多いほど広く動き回る（床の半径 3.5 に収める）
        let areaRadius = min(3.0, 1.5 + 0.12 * Float(characterImages.count))
        for data in characterImages {
            let image = await Task.detached(priority: .userInitiated) {
                ImageDownsampler.downsample(data, maxPixelSize: EntryImageProcessor.characterLongSide)
            }.value
            guard let image, let character = try? PuffyCharacter.make(from: image) else { continue }
            var wander = WanderComponent()
            wander.areaRadius = areaRadius
            character.position = WanderSystem.randomPoint(radius: areaRadius)
            wander.target = WanderSystem.randomPoint(radius: areaRadius)
            character.components.set(wander)
            characters.addChild(character)
            await Task.yield()
        }
    }
}
