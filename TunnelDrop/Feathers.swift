//
//  Feathers.swift
//  TunnelDrop
//
//  Feather pickups that refill the flutter gauge.
//

import SpriteKit

extension GameScene {

    func createFeather() {
        let feather = SKNode()
        feather.name = "feather"
        feather.zPosition = 5

        // Emoji placeholder until custom art arrives.
        let sprite = SKLabelNode(text: "🪶")
        sprite.fontSize = 44
        sprite.verticalAlignmentMode = .center
        feather.addChild(sprite)

        feather.physicsBody = SKPhysicsBody(circleOfRadius: 26)
        feather.physicsBody?.isDynamic = false
        feather.physicsBody?.categoryBitMask = PhysicsCategory.feather
        feather.physicsBody?.collisionBitMask = 0
        feather.physicsBody?.contactTestBitMask = PhysicsCategory.player

        // Spawn near an upcoming gap so the feather is actually reachable.
        let gapFraction = patternQueue.first ?? CGFloat.random(in: 0.2...0.8)
        let xPosition = gapCenterX(for: gapFraction) + CGFloat.random(in: -50...50)
        feather.position = CGPoint(x: xPosition, y: -80)
        addChild(feather)

        let driftRight = SKAction.moveBy(x: 14, y: 0, duration: 0.7)
        driftRight.timingMode = .easeInEaseOut
        let driftLeft = driftRight.reversed()
        driftLeft.timingMode = .easeInEaseOut
        feather.run(SKAction.repeatForever(SKAction.sequence([driftRight, driftLeft])))

        let moveUp = SKAction.moveBy(x: 0, y: frame.height * 1.5, duration: fallSpeed)
        feather.run(SKAction.sequence([moveUp, SKAction.removeFromParent()]))
    }

    func startFeathers() {
        let create = SKAction.run { [unowned self] in
            self.createFeather()
        }
        let wait = SKAction.wait(forDuration: 5, withRange: 4)
        let sequence = SKAction.sequence([wait, create])
        run(SKAction.repeatForever(sequence), withKey: "featherSpawner")
    }

    func collectFeather(_ feather: SKNode) {
        feather.removeFromParent()
        feathersThisRun += 1
        refillFlutter(featherRefillAmount)
        run(SKAction.playSoundFileNamed("pickUp.mp3", waitForCompletion: false))
    }
}
