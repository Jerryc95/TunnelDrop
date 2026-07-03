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

struct PhysicsCategory {
    static let player: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let rock: UInt32 = 1 << 2
    static let scoreGate: UInt32 = 1 << 3
    static let boundary: UInt32 = 1 << 4
    static let feather: UInt32 = 1 << 5
    static let powerUp: UInt32 = 1 << 6
    static let coin: UInt32 = 1 << 7
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

    var flutterGravity = -0.4
    var flutterDrainPerSecond = 0.12
    var featherRefillAmount = 0.35

    var powerUps = PowerUpState()
    var powerUpLabel: SKLabelNode!
    var magnetRadius: CGFloat = 300

    var patternQueue: [CGFloat] = []

    var coinLabel: SKLabelNode!
    var coinsThisRun = 0
    var coinBalance = UserDefaults.standard.integer(forKey: "coinBalance") {
        didSet {
            UserDefaults.standard.set(coinBalance, forKey: "coinBalance")
            coinLabel?.text = "🪙 \(coinBalance)"
        }
    }
    var flutterMeter = 1.0
    var isFluttering = false
    var flutterBarBackground: SKSpriteNode!
    var flutterBarFill: SKSpriteNode!
    var lastUpdateTime: TimeInterval = 0

    var player: SKSpriteNode!

    var scoreLabel: SKLabelNode!
    var playLabel: SKLabelNode!
    var restartLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!

    var highScore = UserDefaults.standard.integer(forKey: "highScore")
    
    var title: SKSpriteNode!
    var dead: SKSpriteNode!
    
    var gameState = GameState.showingMenu
    
    var backgroundMusic: SKAudioNode!
    
    var score = 0 {
        didSet {
            scoreLabel.text = "SCORE: \(score)"
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
        player.physicsBody!.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.rock | PhysicsCategory.scoreGate | PhysicsCategory.feather | PhysicsCategory.powerUp | PhysicsCategory.coin
        player.physicsBody?.isDynamic = true
        
        player.physicsBody?.allowsRotation = false
//        player.physicsBody?.restitution = 1
        player.physicsBody?.friction = 0
       
        let playerFrame2 = SKTexture(imageNamed: "player-2")
        let playerFrame3 = SKTexture(imageNamed: "player-3")
        let playerFrame4 = SKTexture(imageNamed: "player-4")
        let playerFrame5 = SKTexture(imageNamed: "player-5")
        
        let playerAnimation = SKAction.animate(with: [playerTexture, playerFrame2, playerFrame3, playerFrame4, playerFrame5], timePerFrame: flapSpeed)
        let flyForever = SKAction.repeatForever(playerAnimation)
        
        player.run(flyForever)
    }
    
    func createDirt() {
        let dirt = SKSpriteNode(color: UIColor(hue: 360, saturation: 0.25, brightness: 0.24, alpha: 1), size: CGSize(width: frame.width, height: frame.height))
        dirt.anchorPoint = CGPoint(x: 0, y: 0)
        
        addChild(dirt)
        dirt.zPosition = -50
    }
    
    func createWalls() {
        let leftWallTexture = SKTexture(imageNamed: "wallLeft")
        let rightWallTexture = SKTexture(imageNamed: "wallRight")
        
        
        for i in 0...1 {
            let leftWall = SKSpriteNode(texture: leftWallTexture)
            let rightWall = SKSpriteNode(texture: rightWallTexture)
            
            leftWall.physicsBody = texturePhysicsBody(texture: leftWallTexture, size: CGSize(width: leftWall.frame.width * 0.98, height: leftWall.frame.height))
            leftWall.physicsBody?.isDynamic = false
            leftWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            
            leftWall.name = "leftWall"
            leftWall.zPosition = -30
            leftWall.position = CGPoint(x: 35, y: (-leftWallTexture.size().height * CGFloat(i)) + frame.midY)
            
            addChild(leftWall)
            
            
            rightWall.physicsBody = texturePhysicsBody(texture: rightWallTexture, size: CGSize(width: rightWall.frame.width * 0.98, height: leftWall.frame.height))
            rightWall.physicsBody?.isDynamic = false
            rightWall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            
            rightWall.name = "rightWall"
            rightWall.zPosition = -30
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
        
        leftRock.zPosition = -40
        leftRock.name = "leftRock"
        
        rightRock.zPosition = -40
        rightRock.xScale = -1
        rightRock.name = "rightRock"
        
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
        scoreLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        scoreLabel.fontSize = 40
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 115)
        scoreLabel.text = "SCORE: 0"
        scoreLabel.fontColor = UIColor.white
        scoreLabel.alpha = 0

        addChild(scoreLabel)
    }

    func createFlutterGauge() {
        let barSize = CGSize(width: 300, height: 16)

        flutterBarBackground = SKSpriteNode(color: UIColor(white: 0.1, alpha: 0.6), size: barSize)
        flutterBarBackground.position = CGPoint(x: frame.midX, y: frame.maxY - 150)
        flutterBarBackground.zPosition = 90
        flutterBarBackground.alpha = 0
        addChild(flutterBarBackground)

        flutterBarFill = SKSpriteNode(color: UIColor.cyan, size: barSize)
        flutterBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        flutterBarFill.position = CGPoint(x: -barSize.width / 2, y: 0)
        flutterBarFill.zPosition = 1
        flutterBarBackground.addChild(flutterBarFill)
    }

    func refillFlutter(_ amount: Double) {
        flutterMeter = min(flutterMeter + amount, 1.0)
    }
    
    func gameOver() {
        guard gameState == .playing else { return }
        if powerUps.lives > 0 {
            powerUps.lives -= 1
            revive()
            return
        }
        player.removeFromParent()
        dead.alpha = 1
        restartLabel.alpha = 1
        gameState = .dead
        speed = 0
        let deathSound = SKAction.playSoundFileNamed("death.mp3", waitForCompletion: false)
        run(deathSound)
        backgroundMusic.run(SKAction.stop())
        motionManager.stopAccelerometerUpdates()

        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
        }
        highScoreLabel.text = "BEST: \(highScore)"
        highScoreLabel.alpha = 1
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

        guard gameState == .playing else { return }

        updatePowerUps(deltaTime: deltaTime)

        let flutterActive = isFluttering && flutterMeter > 0
        if flutterActive {
            flutterMeter = max(flutterMeter - flutterDrainPerSecond * deltaTime, 0)
        }
        player.speed = flutterActive ? 2.0 : 1.0
        flutterBarFill.xScale = CGFloat(flutterMeter)
        flutterBarFill.color = flutterMeter > 0.25 ? UIColor.cyan : UIColor.red

        if let accelerometerData = motionManager.accelerometerData {
            physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.x * tiltSensitivity, dy: flutterActive ? flutterGravity : fallGravity)
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if collision == PhysicsCategory.player | PhysicsCategory.coin {
            let coin = contact.bodyA.categoryBitMask == PhysicsCategory.coin ? contact.bodyA.node : contact.bodyB.node
            if let coin {
                collectCoin(coin)
            }
            return
        }

        if collision == PhysicsCategory.player | PhysicsCategory.powerUp {
            let node = contact.bodyA.categoryBitMask == PhysicsCategory.powerUp ? contact.bodyA.node : contact.bodyB.node
            if let powerUp = node as? PowerUpNode {
                collectPowerUp(powerUp)
            }
            return
        }

        if collision == PhysicsCategory.player | PhysicsCategory.feather {
            let feather = contact.bodyA.categoryBitMask == PhysicsCategory.feather ? contact.bodyA.node : contact.bodyB.node
            if let feather {
                collectFeather(feather)
            }
            return
        }

        if collision == PhysicsCategory.player | PhysicsCategory.scoreGate {
            let gate = contact.bodyA.categoryBitMask == PhysicsCategory.scoreGate ? contact.bodyA.node : contact.bodyB.node
            gate?.removeFromParent()

            let successSound = SKAction.playSoundFileNamed("success.mp3", waitForCompletion: false)
            run(successSound)
            score += powerUps.scoreMultiplier

            tiltSensitivity = min(tiltSensitivity + 1.75, maxTiltSensitivity)
            return
        }

        if collision & (PhysicsCategory.wall | PhysicsCategory.rock) != 0 {
            gameOver()
        }
    }
    
    
  
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch gameState {
        case .showingMenu:
            gameState = .playing
            
            let fadeOut = SKAction.fadeOut(withDuration: 0.5)
                   let remove = SKAction.removeFromParent()
                   let wait = SKAction.wait(forDuration: 0.5)
                   let activatePlayer = SKAction.run { [unowned self] in
                       tiltSensitivity = 5.0
                       scoreLabel.alpha = 1
                       playLabel.alpha = 0
                       highScoreLabel.alpha = 0
                       flutterBarBackground.alpha = 1
                       self.startRocks()
                       self.startFeathers()
                       self.startPowerUps()
                       self.startCoins()
                   }
            
            let sequence = SKAction.sequence([fadeOut, wait, activatePlayer, remove])
                  title.run(sequence)
        case .playing:
            isFluttering = true
        case .dead:
            if let scene = GameScene(fileNamed: "GameScene") {
                scene.scaleMode = .aspectFill
                let transition = SKTransition.moveIn(with: SKTransitionDirection.down, duration: 1)
                view?.presentScene(scene, transition: transition)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFluttering = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isFluttering = false
    }
}
