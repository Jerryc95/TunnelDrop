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

        feather.position = CGPoint(x: CGFloat.random(in: frame.width * 0.25...frame.width * 0.75), y: -80)
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
        refillFlutter(featherRefillAmount)
        run(SKAction.playSoundFileNamed("pickUp.mp3", waitForCompletion: false))
    }
}
