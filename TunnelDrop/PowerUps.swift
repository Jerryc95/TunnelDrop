//
//  PowerUps.swift
//  TunnelDrop
//
//  Collectible power-ups: magnet, score multiplier, ghost mode, extra lives.
//

import SpriteKit

enum PowerUpType: CaseIterable {
    case magnet
    case multiplier
    case ghost
    case extraLife

    // Emoji placeholders until custom art arrives.
    var emoji: String {
        switch self {
        case .magnet: return "🧲"
        case .multiplier: return "⭐️"
        case .ghost: return "👻"
        case .extraLife: return "❤️"
        }
    }

    var duration: Double {
        switch self {
        case .magnet: return 8
        case .multiplier: return 10
        case .ghost: return 5 // base; upgrades extend via GameScene.ghostDuration
        case .extraLife: return 0
        }
    }
}

struct PowerUpState {
    var magnetTime = 0.0
    var multiplierTime = 0.0
    var ghostTime = 0.0
    var lives = 0
    var reviveTime = 0.0
}

class PowerUpNode: SKNode {
    var type = PowerUpType.magnet
}

extension GameScene {

    func createPowerUp() {
        let powerUp = PowerUpNode()
        powerUp.type = PowerUpType.allCases.randomElement()!
        powerUp.zPosition = 5

        let sprite = SKLabelNode(text: powerUp.type.emoji)
        sprite.fontSize = 48
        sprite.verticalAlignmentMode = .center
        powerUp.addChild(sprite)

        powerUp.physicsBody = SKPhysicsBody(circleOfRadius: 28)
        powerUp.physicsBody?.isDynamic = false
        powerUp.physicsBody?.categoryBitMask = PhysicsCategory.powerUp
        powerUp.physicsBody?.collisionBitMask = 0
        powerUp.physicsBody?.contactTestBitMask = PhysicsCategory.player

        // Spawn near an upcoming gap so the power-up is actually reachable.
        let gapFraction = patternQueue.first ?? CGFloat.random(in: 0.2...0.8)
        let xPosition = gapCenterX(for: gapFraction) + CGFloat.random(in: -50...50)
        powerUp.position = CGPoint(x: xPosition, y: -80)
        addChild(powerUp)

        let pulseUp = SKAction.scale(to: 1.2, duration: 0.5)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.5)
        pulseDown.timingMode = .easeInEaseOut
        powerUp.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))

        let moveUp = SKAction.moveBy(x: 0, y: frame.height * 1.5, duration: fallSpeed)
        powerUp.run(SKAction.sequence([moveUp, SKAction.removeFromParent()]))
    }

    func startPowerUps() {
        let create = SKAction.run { [unowned self] in
            self.createPowerUp()
        }
        let wait = SKAction.wait(forDuration: 18, withRange: 12)
        let sequence = SKAction.sequence([wait, create])
        run(SKAction.repeatForever(sequence), withKey: "powerUpSpawner")
    }

    func collectPowerUp(_ powerUp: PowerUpNode) {
        powerUpsCollectedThisRun += 1
        switch powerUp.type {
        case .magnet:
            powerUps.magnetTime = powerUp.type.duration
        case .multiplier:
            powerUps.multiplierTime = powerUp.type.duration
        case .ghost:
            powerUps.ghostTime = ghostDuration
            ghostUsesThisRun += 1
        case .extraLife:
            powerUps.lives = min(powerUps.lives + 1, 3)
        }
        powerUp.removeFromParent()
        run(SKAction.playSoundFileNamed("pickUp.mp3", waitForCompletion: false))
    }

    func createPowerUpHUD() {
        powerUpLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        powerUpLabel.fontSize = 24
        powerUpLabel.position = CGPoint(x: frame.midX, y: hudTopY - 155)
        powerUpLabel.fontColor = UIColor.white
        powerUpLabel.zPosition = 90
        powerUpLabel.text = ""
        addChild(powerUpLabel)
    }

    func updatePowerUps(deltaTime: Double) {
        powerUps.magnetTime = max(powerUps.magnetTime - deltaTime, 0)
        powerUps.multiplierTime = max(powerUps.multiplierTime - deltaTime, 0)
        powerUps.ghostTime = max(powerUps.ghostTime - deltaTime, 0)
        powerUps.reviveTime = max(powerUps.reviveTime - deltaTime, 0)

        if powerUps.magnetTime > 0 {
            let playerPosition = player.position
            let pull = min(1.0, deltaTime * magnetPull)
            enumerateChildNodes(withName: "feather") { [magnetRadius] node, _ in
                let dx = playerPosition.x - node.position.x
                let dy = playerPosition.y - node.position.y
                if hypot(dx, dy) < magnetRadius {
                    node.position.x += dx * pull
                    node.position.y += dy * pull
                }
            }
        }

        refreshPlayerPhysics()
        updatePowerUpHUD()
    }

    // Player masks and appearance derive from power-up state each frame, so
    // overlapping effects (ghost + revive) can't clobber each other's cleanup.
    func refreshPlayerPhysics() {
        let ghostActive = powerUps.ghostTime > 0
        let invincible = powerUps.reviveTime > 0

        var collide = PhysicsCategory.wall | PhysicsCategory.rock | PhysicsCategory.boundary
        var contact = PhysicsCategory.wall | PhysicsCategory.rock | PhysicsCategory.scoreGate | PhysicsCategory.feather | PhysicsCategory.powerUp

        if ghostActive || invincible {
            collide &= ~PhysicsCategory.rock
            contact &= ~PhysicsCategory.rock
        }
        if invincible {
            collide &= ~PhysicsCategory.wall
            contact &= ~PhysicsCategory.wall
        }

        player.physicsBody?.collisionBitMask = collide
        player.physicsBody?.contactTestBitMask = contact
        player.alpha = (ghostActive || invincible) ? 0.5 : 1.0
    }

    func updatePowerUpHUD() {
        comboBadge.isHidden = powerUps.multiplierTime <= 0

        var parts: [String] = []
        if powerUps.magnetTime > 0 { parts.append("🧲\(Int(powerUps.magnetTime.rounded(.up)))") }
        if powerUps.ghostTime > 0 { parts.append("👻\(Int(powerUps.ghostTime.rounded(.up)))") }
        if powerUps.lives > 0 { parts.append("❤️\(powerUps.lives)") }
        powerUpLabel.text = parts.joined(separator: "   ")
    }

    // Consumes an extra life: brief invincibility instead of death.
    func revive() {
        powerUps.reviveTime = 2.5
        player.physicsBody?.velocity = .zero
        refreshPlayerPhysics()
        updatePowerUpHUD()
    }
}
