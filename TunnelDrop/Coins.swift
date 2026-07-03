//
//  Coins.swift
//  TunnelDrop
//
//  Coin pickups and the persistent coin balance for shop purchases.
//

import SpriteKit

extension GameScene {

    func createCoin() {
        let coin = SKNode()
        coin.name = "coin"
        coin.zPosition = 5

        // Emoji placeholder until custom art arrives.
        let sprite = SKLabelNode(text: "🪙")
        sprite.fontSize = 38
        sprite.verticalAlignmentMode = .center
        coin.addChild(sprite)

        coin.physicsBody = SKPhysicsBody(circleOfRadius: 22)
        coin.physicsBody?.isDynamic = false
        coin.physicsBody?.categoryBitMask = PhysicsCategory.coin
        coin.physicsBody?.collisionBitMask = 0
        coin.physicsBody?.contactTestBitMask = PhysicsCategory.player

        // Spawn near an upcoming gap so the coin is actually reachable.
        let gapFraction = patternQueue.first ?? CGFloat.random(in: 0.2...0.8)
        let xPosition = gapCenterX(for: gapFraction) + CGFloat.random(in: -60...60)
        coin.position = CGPoint(x: xPosition, y: -80)
        addChild(coin)

        let pulseUp = SKAction.scale(to: 1.15, duration: 0.4)
        pulseUp.timingMode = .easeInEaseOut
        let pulseDown = SKAction.scale(to: 1.0, duration: 0.4)
        pulseDown.timingMode = .easeInEaseOut
        coin.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))

        let moveUp = SKAction.moveBy(x: 0, y: frame.height * 1.5, duration: fallSpeed)
        coin.run(SKAction.sequence([moveUp, SKAction.removeFromParent()]))
    }

    func startCoins() {
        let create = SKAction.run { [unowned self] in
            self.createCoin()
        }
        let wait = SKAction.wait(forDuration: 3.5, withRange: 3)
        let sequence = SKAction.sequence([wait, create])
        run(SKAction.repeatForever(sequence), withKey: "coinSpawner")
    }

    func collectCoin(_ coin: SKNode) {
        coin.removeFromParent()
        // The score multiplier power-up doubles coin earnings too.
        let earned = powerUps.scoreMultiplier
        coinsThisRun += earned
        coinBalance += earned
        run(SKAction.playSoundFileNamed("pickUp.mp3", waitForCompletion: false))
    }

    func createCoinHUD() {
        coinLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        coinLabel.fontSize = 30
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: 40, y: frame.maxY - 115)
        coinLabel.fontColor = UIColor.white
        coinLabel.zPosition = 90
        coinLabel.text = "🪙 \(coinBalance)"
        addChild(coinLabel)
    }
}
