//
//  WanderSystem.swift
//  CalenderPicture（DanceImage から移植）
//
//  キャラクターを床の上でぴょこぴょこ動き回らせ、ときどきその場でくるくる踊らせる。
//

import RealityKit
import simd

struct WanderComponent: Component {
    /// 動き回れる範囲（原点からの半径）
    var areaRadius: Float = 2.5
    var target: SIMD3<Float> = .zero
    var speed: Float = .random(in: 0.5...0.9)
    var phase: Float = .random(in: 0...(2 * .pi))
    var yaw: Float = .random(in: -.pi...(.pi))
    var danceTimeLeft: Float = 0
    var nextDanceIn: Float = .random(in: 4...10)
}

struct WanderSystem: System {
    private static let query = EntityQuery(where: .has(WanderComponent.self))

    init(scene: Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(min(context.deltaTime, 1.0 / 20))
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard var wander = entity.components[WanderComponent.self],
                  let body = entity.findEntity(named: "body") else { continue }

            var hop: Float
            var roll: Float
            var stretch: Float

            if wander.danceTimeLeft > 0 {
                // ダンス: 高く跳ねながらくるくる回る
                wander.danceTimeLeft -= dt
                wander.phase += dt * 9
                wander.yaw += dt * 5
                hop = abs(sin(wander.phase)) * 0.25
                roll = sin(wander.phase * 0.5) * 0.2
                stretch = 1 + 0.12 * cos(wander.phase * 2)
                if wander.danceTimeLeft <= 0 {
                    wander.nextDanceIn = .random(in: 5...12)
                }
            } else {
                // 歩き回り: 目的地に向かって体を左右に揺らしながら跳ねる
                var toTarget = wander.target - entity.position
                toTarget.y = 0
                let distance = simd_length(toTarget)
                if distance < 0.1 {
                    wander.target = Self.randomPoint(radius: wander.areaRadius)
                } else {
                    let direction = toTarget / distance
                    entity.position += direction * min(distance, wander.speed * dt)
                    let desiredYaw = atan2(direction.x, direction.z)
                    let diff = atan2(sin(desiredYaw - wander.yaw), cos(desiredYaw - wander.yaw))
                    wander.yaw += diff * min(1, dt * 4)
                }
                wander.phase += dt * wander.speed * 11
                hop = abs(sin(wander.phase)) * 0.08
                roll = sin(wander.phase) * 0.12
                stretch = 1 + 0.06 * cos(wander.phase * 2)

                wander.nextDanceIn -= dt
                if wander.nextDanceIn <= 0 {
                    wander.danceTimeLeft = .random(in: 2...3.5)
                }
            }

            entity.orientation = simd_quatf(angle: wander.yaw, axis: [0, 1, 0])
            body.position = [0, hop, 0]
            body.orientation = simd_quatf(angle: roll, axis: [0, 0, 1])
            // 体積を保つように縦に伸びたら横に縮む
            let squash = 1 / stretch.squareRoot()
            body.scale = [squash, stretch, squash]

            entity.components[WanderComponent.self] = wander
        }
    }

    static func randomPoint(radius: Float) -> SIMD3<Float> {
        let angle = Float.random(in: 0...(2 * .pi))
        let r = radius * Float.random(in: 0...1).squareRoot()
        return [cos(angle) * r, 0, sin(angle) * r]
    }
}
