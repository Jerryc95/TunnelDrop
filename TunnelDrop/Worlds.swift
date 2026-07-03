//
//  Worlds.swift
//  TunnelDrop
//
//  Environments: the player picks a starting world, and the environment
//  advances to the next world as the run progresses. Reaching a world
//  unlocks it as a starting option. Color treatments stand in for
//  per-world art until custom assets arrive.
//

import SpriteKit

struct World {
    let name: String
    let dirtColor: UIColor
    let tint: UIColor
    let tintBlend: CGFloat

    static let all: [World] = [
        World(name: "Cave",
              dirtColor: UIColor(hue: 1, saturation: 0.25, brightness: 0.24, alpha: 1),
              tint: UIColor(red: 0.45, green: 0.33, blue: 0.25, alpha: 1),
              tintBlend: 0),
        World(name: "Crystal",
              dirtColor: UIColor(hue: 0.74, saturation: 0.38, brightness: 0.22, alpha: 1),
              tint: UIColor(red: 0.55, green: 0.42, blue: 0.85, alpha: 1),
              tintBlend: 0.35),
        World(name: "Tide",
              dirtColor: UIColor(hue: 0.52, saturation: 0.45, brightness: 0.20, alpha: 1),
              tint: UIColor(red: 0.25, green: 0.65, blue: 0.70, alpha: 1),
              tintBlend: 0.35),
        World(name: "Grove",
              dirtColor: UIColor(hue: 0.33, saturation: 0.40, brightness: 0.18, alpha: 1),
              tint: UIColor(red: 0.35, green: 0.65, blue: 0.35, alpha: 1),
              tintBlend: 0.35),
    ]
}

extension GameScene {

    func applyWorld(_ index: Int, animated: Bool) {
        let world = World.all[index]
        let duration = animated ? 1.2 : 0

        dirtNode.run(SKAction.colorize(with: world.dirtColor, colorBlendFactor: 1, duration: duration))
        for name in ["leftWall", "rightWall", "leftRock", "rightRock"] {
            enumerateChildNodes(withName: name) { node, _ in
                (node as? SKSpriteNode)?.run(SKAction.colorize(with: world.tint, colorBlendFactor: world.tintBlend, duration: duration))
            }
        }
    }

    func advanceWorldIfNeeded() {
        let target = min(startWorldIndex + score / scorePerWorld, World.all.count - 1)
        guard target != worldIndex else { return }
        worldIndex = target
        applyWorld(worldIndex, animated: true)
    }
}
