//
//  GameScene.swift
//  TunnelDrop
//
//  Created by Jerry Cox on 2/3/24.
//

import SpriteKit
import CoreMotion

enum GameState {
    case showingMenu
    case playing
    case dead
}

struct GameResult {
    let score: Int
    let coinsEarned: Int
    let previousBest: Int
    let isNewBest: Bool
}

struct PhysicsCategory {
    static let player: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let rock: UInt32 = 1 << 2
    static let scoreGate: UInt32 = 1 << 3
    static let boundary: UInt32 = 1 << 4
    static let feather: UInt32 = 1 << 5
    static let powerUp: UInt32 = 1 << 6
}

// SKPhysicsBody(texture:) traps with EXC_BREAKPOINT in the iOS simulator (long-standing
// SpriteKit bug), so simulator builds use approximate shape bodies; devices keep
// pixel-accurate texture bodies.
func texturePhysicsBody(texture: SKTexture, size: CGSize) -> SKPhysicsBody {
    #if targetEnvironment(simulator)
    return SKPhysicsBody(rectangleOf: size)
    #else
    return SKPhysicsBody(texture: texture, size: size)
    #endif
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var motionManager = CMMotionManager()
    var tiltSensitivity = 0.0
    var maxTiltSensitivity = 40.0
    var flapSpeed = 0.15
    var fallSpeed = 10.0
    var fallGravity = -5.0

    var flutterGravity = -0.1
    var flutterDrainPerSecond = 0.18
    var featherRefillAmount = 0.2

    var powerUps = PowerUpState()
    var powerUpLabel: SKLabelNode!
    var magnetRadius: CGFloat = 300

    var patternQueue: [CGFloat] = []

    var dirtNode: SKSpriteNode!
    var worldIndex = 0
    var startWorldIndex = 0
    var scorePerWorld = 25

    var coinLabel: SKLabelNode!
    var coinsThisRun = 0
    var scorePerCoin = 20
    var flutterUsesThisRun = 0
    var gatesThisRun = 0
    var coinBalance = UserDefaults.standard.integer(forKey: "coinBalance") {
        didSet {
            UserDefaults.standard.set(coinBalance, forKey: "coinBalance")
        }
    }

    // .aspectFill crops the 750x1334 scene horizontally on tall phones (and
    // vertically on iPads), so HUD anchors derive from the visible region.
    var hudInsetX: CGFloat {
        guard let view else { return 0 }
        let scale = max(view.bounds.width / frame.width, view.bounds.height / frame.height)
        return (frame.width - view.bounds.width / scale) / 2
    }

    var hudTopY: CGFloat {
        guard let view else { return frame.maxY - 105 }
        let scale = max(view.bounds.width / frame.width, view.bounds.height / frame.height)
        let cropY = (frame.height - view.bounds.height / scale) / 2
        return frame.maxY - cropY - 105
    }
    var flutterMeter = 1.0
    var isFluttering = false
    var flutterBarBackground: SKSpriteNode!
    var flutterBarFill: SKSpriteNode!
    var lastUpdateTime: TimeInterval = 0

    var player: SKSpriteNode!

    var scoreLabel: SKLabelNode!
    var scoreCaption: SKLabelNode!
    var comboBadge: SKLabelNode!
    var pauseButton: SKLabelNode!
    var pausedLabel: SKLabelNode!
    var playLabel: SKLabelNode!
    var restartLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!

    var highScore = UserDefaults.standard.integer(forKey: "highScore")
    
    var title: SKSpriteNode!
    var dead: SKSpriteNode!
    
    var gameState = GameState.showingMenu

    var onGameOver: ((GameResult) -> Void)?
    
    var backgroundMusic: SKAudioNode!
    
    var score = 0 {
        didSet {
            scoreLabel.text = "\(score)"
            coinLabel?.text = "🪙 \(score / scorePerCoin)"
        }
    }
    
    func createPlayer() {
        let playerTexture = SKTexture(imageNamed: "player-1")
        player = SKSpriteNode(texture: playerTexture)
        player.zPosition = 10
        player.position = CGPoint(x: frame.width / 2, y: frame.height * 0.68)
        
        addChild(player)
        
        #if targetEnvironment(simulator)
        player.physicsBody = SKPhysicsBody(circleOfRadius: playerTexture.size().height / 2)
        #else
        player.physicsBody = SKPhysicsBody(texture: playerTexture, size: playerTexture.size())
        #endif
        player.physicsBody!.categoryBitMask = PhysicsCategory.player
        player.physicsBody!.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.rock | PhysicsCategory.boundary
        player.physicsBody!.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.rock | PhysicsCategory.scoreGate | PhysicsCategory.feather | PhysicsCategory.powerUp
        player.physicsBody?.isDynamic = true
        
        player.physicsBody?.allowsRotation = false
//        player.physicsBody?.restitution = 1
        player.physicsBody?.friction = 0

        if let tint = Skin.equipped().tint {
            player.color = tint
            player.colorBlendFactor = 0.55
        }
       
        let playerFrame2 = SKTexture(imageNamed: "player-2")
        let playerFrame3 = SKTexture(imageNamed: "player-3")
        let playerFrame4 = SKTexture(imageNamed: "player-4")
        let playerFrame5 = SKTexture(imageNamed: "player-5")
        
        let playerAnimation = SKAction.animate(with: [playerTexture, playerFrame2, playerFrame3, playerFrame4, playerFrame5], timePerFrame: flapSpeed)
        let flyForever = SKAction.repeatForever(playerAnimation)
        
        player.run(flyForever)
    }
    
    func createDirt() {
        dirtNode = SKSpriteNode(color: World.all[worldIndex].dirtColor, size: CGSize(width: frame.width, height: frame.height))
        dirtNode.anchorPoint = CGPoint(x: 0, y: 0)

        addChild(dirtNode)
        dirtNode.zPosition = -50
    }
    
    func createWalls() {
        let leftWallTexture = SKTexture(imageNamed: "wallLeft")
        let rightWallTexture = SKTexture(imageNamed: "wallRight")
        let world = World.all[worldIndex]
        
        
        for i in 0...1 {
            let leftWall = SKSpriteNode(texture: leftWallTexture)
            let rightWall = SKSpriteNode(texture: rightWallTexture)
            
            leftWall.physicsBody = texturePhysicsBody(texture: leftWallTexture, size: CGSize(width: leftWall.frame.width * 0.98, height: leftWall.frame.height))
            leftWall.physicsBody?.isDynamic = false
            leftWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            
            leftWall.name = "leftWall"
            leftWall.zPosition = -30
            leftWall.color = world.tint
            leftWall.colorBlendFactor = world.tintBlend
            leftWall.position = CGPoint(x: 35, y: (-leftWallTexture.size().height * CGFloat(i)) + frame.midY)
            
            addChild(leftWall)
            
            
            rightWall.physicsBody = texturePhysicsBody(texture: rightWallTexture, size: CGSize(width: rightWall.frame.width * 0.98, height: leftWall.frame.height))
            rightWall.physicsBody?.isDynamic = false
            rightWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            
            rightWall.name = "rightWall"
            rightWall.zPosition = -30
            rightWall.color = world.tint
            rightWall.colorBlendFactor = world.tintBlend
            rightWall.position = CGPoint(x: frame.maxX - 35, y: (-rightWallTexture.size().height * CGFloat(i)) + frame.midY)
            
            addChild(rightWall)
            
            let moveUp = SKAction.moveBy(x: 0, y: rightWallTexture.size().height, duration: fallSpeed + 0.15)
            let moveReset = SKAction.moveBy(x: 0, y: -rightWallTexture.size().height , duration: 0)
            let moveLoop = SKAction.sequence([moveUp, moveReset])
            let moveForever = SKAction.repeatForever(moveLoop)
            
            leftWall.run(moveForever)
            rightWall.run(moveForever)
        }
    }
    
    func createRocks() {
        let rockTexture = SKTexture(imageNamed: "rockLeftLong")
        let leftRock = SKSpriteNode(texture: rockTexture)
        let rightRock = SKSpriteNode(texture: rockTexture)
        
        leftRock.physicsBody = texturePhysicsBody(texture: rockTexture, size: leftRock.size)
        leftRock.physicsBody?.isDynamic = false
        leftRock.physicsBody?.categoryBitMask = PhysicsCategory.rock

        rightRock.physicsBody = texturePhysicsBody(texture: rockTexture, size: rightRock.size)
        rightRock.physicsBody?.isDynamic = false
        rightRock.physicsBody?.categoryBitMask = PhysicsCategory.rock
        
        let world = World.all[worldIndex]

        leftRock.zPosition = -40
        leftRock.name = "leftRock"
        leftRock.color = world.tint
        leftRock.colorBlendFactor = world.tintBlend

        rightRock.zPosition = -40
        rightRock.xScale = -1
        rightRock.name = "rightRock"
        rightRock.color = world.tint
        rightRock.colorBlendFactor = world.tintBlend
        
        let scoreCollision = SKSpriteNode(color: UIColor.red, size: CGSize(width: frame.width * 2, height: 35))
        scoreCollision.physicsBody = SKPhysicsBody(rectangleOf: scoreCollision.size)
        scoreCollision.physicsBody?.isDynamic = false
        scoreCollision.physicsBody?.categoryBitMask = PhysicsCategory.scoreGate
        scoreCollision.physicsBody?.collisionBitMask = 0
        scoreCollision.physicsBody?.contactTestBitMask = PhysicsCategory.player
        scoreCollision.alpha = 0
        scoreCollision.name = "detectScore"
        
        addChild(leftRock)
        addChild(rightRock)
        addChild(scoreCollision)
        
        let yPosition = CGFloat.random(in: -120...0)
        let halfGap: CGFloat = 100
        let gapCenter = gapCenterX(for: nextGapPosition())

        leftRock.position = CGPoint(x: gapCenter - halfGap - leftRock.frame.width / 2, y: yPosition)
        rightRock.position = CGPoint(x: gapCenter + halfGap + rightRock.frame.width / 2, y: yPosition)
        scoreCollision.position = CGPoint(x: 1, y: yPosition - 25)
        
        let endPosition = frame.height * 1.5
        
        let moveAction = SKAction.moveBy(x: 0, y: endPosition, duration: fallSpeed)
        let moveSequence = SKAction.sequence([moveAction, SKAction.removeFromParent()])
        leftRock.run(moveSequence)
        rightRock.run(moveSequence)
        scoreCollision.run(moveSequence)
        
    }
    
    func startRocks() {
        let create = SKAction.run { [unowned self] in
            self.createRocks()
        }
        
        let wait = SKAction.wait(forDuration: 3)
        let sequence = SKAction.sequence([create, wait])
        let repeatForever = SKAction.repeatForever(sequence)
        
        
        run(repeatForever)
    }
    
    func createScore() {
        scoreCaption = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        scoreCaption.fontSize = 24
        scoreCaption.position = CGPoint(x: frame.midX, y: hudTopY)
        scoreCaption.text = "SCORE"
        scoreCaption.fontColor = UIColor(white: 0.8, alpha: 1)
        scoreCaption.zPosition = 90
        scoreCaption.alpha = 0
        addChild(scoreCaption)

        scoreLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        scoreLabel.fontSize = 68
        scoreLabel.position = CGPoint(x: frame.midX, y: hudTopY - 70)
        scoreLabel.text = "0"
        scoreLabel.fontColor = UIColor.white
        scoreLabel.zPosition = 90
        scoreLabel.alpha = 0
        addChild(scoreLabel)

        comboBadge = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        comboBadge.fontSize = 26
        comboBadge.position = CGPoint(x: frame.midX, y: hudTopY - 115)
        comboBadge.text = "⭐️ x3 COMBO"
        comboBadge.fontColor = UIColor.orange
        comboBadge.zPosition = 90
        comboBadge.isHidden = true
        addChild(comboBadge)

        pauseButton = SKLabelNode(text: "⏸️")
        pauseButton.fontSize = 44
        pauseButton.position = CGPoint(x: frame.minX + hudInsetX + 50, y: hudTopY - 35)
        pauseButton.zPosition = 90
        pauseButton.name = "pauseButton"
        pauseButton.alpha = 0
        addChild(pauseButton)
    }

    func createFlutterGauge() {
        let barSize = CGSize(width: 22, height: 260)

        flutterBarBackground = SKSpriteNode(color: UIColor(white: 0.1, alpha: 0.6), size: barSize)
        flutterBarBackground.position = CGPoint(x: frame.maxX - hudInsetX - 45, y: frame.midY + 120)
        flutterBarBackground.zPosition = 90
        flutterBarBackground.alpha = 0
        addChild(flutterBarBackground)

        flutterBarFill = SKSpriteNode(color: UIColor.cyan, size: barSize)
        flutterBarFill.anchorPoint = CGPoint(x: 0.5, y: 0)
        flutterBarFill.position = CGPoint(x: 0, y: -barSize.height / 2)
        flutterBarFill.zPosition = 1
        flutterBarBackground.addChild(flutterBarFill)

        let bolt = SKLabelNode(text: "⚡️")
        bolt.fontSize = 34
        bolt.verticalAlignmentMode = .center
        bolt.position = CGPoint(x: 0, y: barSize.height / 2 + 34)
        flutterBarBackground.addChild(bolt)

        let caption = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        caption.fontSize = 18
        caption.text = "FLUTTER"
        caption.fontColor = UIColor.cyan
        caption.position = CGPoint(x: 0, y: -barSize.height / 2 - 36)
        flutterBarBackground.addChild(caption)
    }

    func refillFlutter(_ amount: Double) {
        flutterMeter = min(flutterMeter + amount, 1.0)
    }
    
    // Called by GameViewController when the SwiftUI home screen's PLAY
    // (or the game-over card's RETRY) is tapped.
    func startRun() {
        guard gameState == .showingMenu else { return }
        gameState = .playing

        title.removeFromParent()
        playLabel.alpha = 0
        highScoreLabel.alpha = 0

        tiltSensitivity = 5.0
        scoreLabel.alpha = 1
        scoreCaption.alpha = 1
        pauseButton.alpha = 1
        flutterBarBackground.alpha = 1
        coinLabel.text = "🪙 0"

        startRocks()
        startFeathers()
        startPowerUps()
    }

    func gameOver() {
        guard gameState == .playing else { return }
        // Contacts already queued this frame land after a revive; ignore them.
        guard powerUps.reviveTime <= 0 else { return }
        if powerUps.lives > 0 {
            powerUps.lives -= 1
            revive()
            return
        }
        player.removeFromParent()
        gameState = .dead
        speed = 0
        let deathSound = SKAction.playSoundFileNamed("death.mp3", waitForCompletion: false)
        run(deathSound)
        backgroundMusic.run(SKAction.stop())
        motionManager.stopAccelerometerUpdates()
        pauseButton.alpha = 0
        comboBadge.isHidden = true

        let previousBest = highScore
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
        }
        coinsThisRun = score / scorePerCoin
        coinBalance += coinsThisRun
        DailyChallengeStore.shared.recordRun(score: score, coins: coinsThisRun, flutterUses: flutterUsesThisRun, gates: gatesThisRun)

        let result = GameResult(score: score, coinsEarned: coinsThisRun, previousBest: previousBest, isNewBest: score > previousBest)
        // Scene speed is 0, so SKAction-based delays never fire; use GCD.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.onGameOver?(result)
        }
    }
    
    func createScreens() {
        title = SKSpriteNode(imageNamed: "logo")
        title.position = CGPoint(x: frame.midX, y: frame.maxY - 220)
        addChild(title)
        
        playLabel = SKLabelNode(fontNamed: "Courier")
        playLabel.fontSize = 30
        playLabel.position = CGPoint(x: frame.midX, y: frame.minY + 150)
        playLabel.text = "TAP TO PLAY"
        playLabel.fontColor = UIColor.white
        addChild(playLabel)
        
        dead = SKSpriteNode(imageNamed: "gameOver")
        dead.position = CGPoint(x: frame.midX, y: frame.midY)
        dead.alpha = 0
        addChild(dead)
        
        restartLabel = SKLabelNode(fontNamed: "Courier")
        restartLabel.fontSize = 30
        restartLabel.position = CGPoint(x: frame.midX, y: frame.minY + 150)
        restartLabel.text = "TAP TO TRY AGAIN"
        restartLabel.fontColor = UIColor.white
        restartLabel.alpha = 0
        addChild(restartLabel)

        pausedLabel = SKLabelNode(fontNamed: "Courier")
        pausedLabel.fontSize = 30
        pausedLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        pausedLabel.text = "PAUSED - TAP TO RESUME"
        pausedLabel.fontColor = UIColor.white
        pausedLabel.zPosition = 100
        pausedLabel.isHidden = true
        addChild(pausedLabel)

        highScoreLabel = SKLabelNode(fontNamed: "Courier")
        highScoreLabel.fontSize = 24
        highScoreLabel.position = CGPoint(x: frame.midX, y: frame.minY + 200)
        highScoreLabel.text = "BEST: \(highScore)"
        highScoreLabel.fontColor = UIColor.white
        addChild(highScoreLabel)
    }
    
    override func didMove(to view: SKView) {
        createPlayer()
        createDirt()
        createWalls()
        createScore()
        createFlutterGauge()
        createPowerUpHUD()
        createCoinHUD()
        createScreens()

        motionManager.startAccelerometerUpdates()

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero

        physicsBody = SKPhysicsBody(edgeLoopFrom: frame.inset(by: UIEdgeInsets(top: 700, left: 0, bottom: 400, right: 0)))
        physicsBody?.categoryBitMask = PhysicsCategory.boundary
        
        if let musicURL = Bundle.main.url(forResource: "music", withExtension: "m4a") {
            backgroundMusic = SKAudioNode(url: musicURL)
            addChild(backgroundMusic)
            backgroundMusic.run(SKAction.changeVolume(to: Float(0.15), duration: 0))
        }
        
        

    }
    
    
    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime > 0 ? min(currentTime - lastUpdateTime, 1.0 / 30.0) : 0
        lastUpdateTime = currentTime

        guard gameState == .playing && !isPaused else { return }

        updatePowerUps(deltaTime: deltaTime)

        let flutterActive = isFluttering && flutterMeter > 0
        if flutterActive {
            flutterMeter = max(flutterMeter - flutterDrainPerSecond * deltaTime, 0)
        }
        player.speed = flutterActive ? 2.0 : 1.0
        flutterBarFill.yScale = CGFloat(flutterMeter)
        flutterBarFill.color = flutterMeter > 0.25 ? UIColor.cyan : UIColor.red

        if let accelerometerData = motionManager.accelerometerData {
            physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.x * tiltSensitivity, dy: flutterActive ? flutterGravity : fallGravity)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        // The player's texture body is decomposed into multiple shapes, so one
        // crossing can fire didBegin several times. Requiring the node to still
        // be in the scene dedupes: the first contact removes it.
        if collision == PhysicsCategory.player | PhysicsCategory.powerUp {
            let node = contact.bodyA.categoryBitMask == PhysicsCategory.powerUp ? contact.bodyA.node : contact.bodyB.node
            if let powerUp = node as? PowerUpNode, powerUp.parent != nil {
                collectPowerUp(powerUp)
            }
            return
        }

        if collision == PhysicsCategory.player | PhysicsCategory.feather {
            let feather = contact.bodyA.categoryBitMask == PhysicsCategory.feather ? contact.bodyA.node : contact.bodyB.node
            if let feather, feather.parent != nil {
                collectFeather(feather)
            }
            return
        }

        if collision == PhysicsCategory.player | PhysicsCategory.scoreGate {
            let gate = contact.bodyA.categoryBitMask == PhysicsCategory.scoreGate ? contact.bodyA.node : contact.bodyB.node
            guard let gate, gate.parent != nil else { return }
            gate.removeFromParent()

            let successSound = SKAction.playSoundFileNamed("success.mp3", waitForCompletion: false)
            run(successSound)
            gatesThisRun += 1
            score += powerUps.multiplierTime > 0 ? 3 : 1

            tiltSensitivity = min(tiltSensitivity + 1.75, maxTiltSensitivity)
            advanceWorldIfNeeded()
            return
        }

        if collision & (PhysicsCategory.wall | PhysicsCategory.rock) != 0 {
            gameOver()
        }
    }
    
    
  
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameState {
        case .showingMenu:
            // Run start is driven by the SwiftUI home screen via startRun().
            break
        case .playing:
            if isPaused {
                isPaused = false
                pausedLabel.isHidden = true
                return
            }
            if let touch = touches.first,
               nodes(at: touch.location(in: self)).contains(where: { $0.name == "pauseButton" }) {
                isPaused = true
                isFluttering = false
                pausedLabel.isHidden = false
                return
            }
            isFluttering = true
            if flutterMeter > 0 {
                flutterUsesThisRun += 1
            }
        case .dead:
            // Retry/home are driven by the SwiftUI game-over card.
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFluttering = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFluttering = false
    }
}
