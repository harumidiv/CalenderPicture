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
    @State private var style = WanderStyle.crayon

    var body: some View {
        // 削除済みのモデルを非同期処理から触らないよう、値を取り出しておく
        let cast = WanderCast.characters(
            in: month,
            from: entries.map { .init(key: $0.key, character: $0.characterData, cutout: $0.cutoutData) }
        )

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
                } else {
                    Picker("表示", selection: $style) {
                        ForEach(WanderStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                    .padding(6)
                    .background(.regularMaterial, in: .capsule)
                    .accessibilityIdentifier("wander-style")
                }
            }
            .padding()
        }
        .task {
            await stage.show(cast)
        }
        .onChange(of: style) { _, newStyle in
            Task { await stage.setStyle(newStyle) }
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

    /// 1体分の状態。見た目（クレヨン／写真）は body の子のモデルを差し替えて切り替える
    private struct Actor {
        /// 渡された順番（登場の速さは準備の速さで変わるので、並びはこれで揃える）
        let order: Int
        let body: Entity
        let crayon: ModelEntity
        let cutout: Data?
        var photo: ModelEntity?
        var displayed: WanderStyle
    }

    private var actors: [Actor] = []
    private(set) var style = WanderStyle.crayon

    /// 各キャラクターがいま表示している見た目（渡された順）
    var displayedStyles: [WanderStyle] { actors.sorted { $0.order < $1.order }.map(\.displayed) }

    /// キャラクターを登場させる。重い準備は裏のスレッドで並行して行い、できたものから順に登場させる。
    /// 全員そろったら、写真の見た目も裏で準備しておく（初めて切り替えたときに待たせないため）。
    func show(_ members: [WanderCast.Member]) async {
        // 人数が多いほど広く動き回る（床の半径 3.5 に収める）
        let areaRadius = min(3.0, 1.5 + 0.12 * Float(members.count))
        await withTaskGroup(of: (Int, PuffyCharacter.Prepared?).self) { group in
            for (order, member) in members.enumerated() {
                group.addTask { (order, Self.prepare(member.character)) }
            }
            for await (order, prepared) in group {
                // メインスレッドでは RealityKit への登録だけを行う
                guard let prepared, let crayon = try? PuffyCharacter.makeModel(from: prepared) else { continue }
                let body = Entity()
                body.name = "body"
                body.addChild(crayon)
                let root = Entity()
                root.addChild(body)

                var wander = WanderComponent()
                wander.areaRadius = areaRadius
                root.position = WanderSystem.randomPoint(radius: areaRadius)
                wander.target = WanderSystem.randomPoint(radius: areaRadius)
                root.components.set(wander)
                characters.addChild(root)

                actors.append(Actor(order: order, body: body, crayon: crayon, cutout: members[order].cutout,
                                    photo: nil, displayed: .crayon))
                if style == .photo { await applyStyle(to: actors.count - 1) }
            }
        }
        await preparePhotos()
    }

    /// 写真の見た目をまだ作っていないキャラクターの分を、裏で並行して準備する。
    private func preparePhotos() async {
        await withTaskGroup(of: (Int, PuffyCharacter.Prepared?).self) { group in
            for (index, actor) in actors.enumerated() where actor.photo == nil {
                guard let cutout = actor.cutout else { continue }
                group.addTask { (index, Self.prepare(cutout)) }
            }
            for await (index, prepared) in group {
                guard actors[index].photo == nil, let prepared else { continue }
                actors[index].photo = try? PuffyCharacter.makeModel(from: prepared)
                if style == .photo { await applyStyle(to: index) }
            }
        }
    }

    /// 見た目を切り替える。切り抜き写真がないキャラクターはクレヨンのまま。
    func setStyle(_ style: WanderStyle) async {
        self.style = style
        for index in actors.indices {
            await applyStyle(to: index)
        }
    }

    private func applyStyle(to index: Int) async {
        // 裏での準備がまだ終わっていなければ、ここで（裏のスレッドで）準備する
        if style == .photo, actors[index].photo == nil, let cutout = actors[index].cutout,
           let prepared = await Task.detached(priority: .userInitiated, operation: { Self.prepare(cutout) }).value,
           actors[index].photo == nil {
            actors[index].photo = try? PuffyCharacter.makeModel(from: prepared)
        }
        // 写真の読み込み中に切り替えられていても、最新の指定に合わせる
        let model: ModelEntity
        let displayed: WanderStyle
        if style == .photo, let photo = actors[index].photo {
            (model, displayed) = (photo, .photo)
        } else {
            (model, displayed) = (actors[index].crayon, .crayon)
        }
        guard actors[index].displayed != displayed else { return }
        actors[index].body.children.removeAll()
        actors[index].body.addChild(model)
        actors[index].displayed = displayed
    }

    /// 画像の読み込みと立体の形の準備（メインスレッド外で呼ぶ）
    nonisolated private static func prepare(_ data: Data) -> PuffyCharacter.Prepared? {
        guard let image = ImageDownsampler.downsample(data, maxPixelSize: EntryImageProcessor.characterLongSide) else { return nil }
        return try? PuffyCharacter.prepare(from: image)
    }
}
/// キャラクターの見た目
enum WanderStyle: CaseIterable {
    /// クレヨンでデフォルメしたキャラクター
    case crayon
    /// 元写真の切り抜き
    case photo

    var label: String {
        switch self {
        case .crayon: "クレヨン"
        case .photo: "写真"
        }
    }
}
