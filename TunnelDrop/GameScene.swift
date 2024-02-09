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

class GameScene: SKScene, SKPhysicsContactDelegate {
    var motionManager = CMMotionManager()
    var tiltSensitivity = 0.0
    var flapSpeed = 0.15
    var fallSpeed = 10.0
    
    var player: SKSpriteNode!
    
    var scoreLabel: SKLabelNode!
    var playLabel: SKLabelNode!
    var restartLabel: SKLabelNode!
    
    var title: SKSpriteNode!
    var dead: SKSpriteNode!
    
    var gameState = GameState.showingMenu
    
    var backgroundMusic: SKAudioNode!
    
    var score = 0 {
        didSet {
            scoreLabel.text = "SCORE: \(score)"
//
        }
    }
    
    func createPlayer() {
        let playerTexture = SKTexture(imageNamed: "player-1")
        player = SKSpriteNode(texture: playerTexture)
        player.zPosition = 10
        player.position = CGPoint(x: frame.width / 2, y: frame.height * 0.68)
        
        addChild(player)
        
        player.physicsBody = SKPhysicsBody(texture: playerTexture, size: playerTexture.size())
        player.physicsBody!.contactTestBitMask = player.physicsBody!.collisionBitMask
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
            
            leftWall.physicsBody = SKPhysicsBody(texture: leftWallTexture, size: CGSize(width: leftWall.frame.width * 0.98, height: leftWall.frame.height))
            leftWall.physicsBody?.isDynamic = false
            
            leftWall.name = "leftWall"
            leftWall.zPosition = -30
            leftWall.position = CGPoint(x: 35, y: (-leftWallTexture.size().height * CGFloat(i)) + frame.midY)
            
            addChild(leftWall)
            
            
            rightWall.physicsBody = SKPhysicsBody(texture: rightWallTexture, size: CGSize(width: rightWall.frame.width * 0.98, height: leftWall.frame.height))
            rightWall.physicsBody?.isDynamic = false
            
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
        
        leftRock.physicsBody = SKPhysicsBody(texture: rockTexture, size: leftRock.size)
        leftRock.physicsBody?.isDynamic = false
        
        rightRock.physicsBody = SKPhysicsBody(texture: rockTexture, size: rightRock.size)
        rightRock.physicsBody?.isDynamic = false
        
        leftRock.zPosition = -40
        leftRock.name = "leftRock"
        
        rightRock.zPosition = -40
        rightRock.xScale = -1
        rightRock.name = "rightRock"
        
        let scoreCollision = SKSpriteNode(color: UIColor.red, size: CGSize(width: frame.width * 2, height: 35))
        scoreCollision.physicsBody = SKPhysicsBody(rectangleOf: scoreCollision.size)
        scoreCollision.physicsBody?.isDynamic = false
        scoreCollision.alpha = 0
        scoreCollision.name = "detectScore"
        
        addChild(leftRock)
        addChild(rightRock)
        addChild(scoreCollision)
        
        let yPosition = CGFloat.random(in: -120...0)
        let xPosition = leftRock.frame.width + CGFloat.random(in: -260...20)
        let rockDistance: CGFloat = 100
        //        let rockDistance = CGFloat.random(in: 70...130)
        
        leftRock.position = CGPoint(x: xPosition - rockDistance, y: yPosition)
        rightRock.position = CGPoint(x: xPosition + leftRock.frame.width + rockDistance, y: yPosition)
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
    
    func gameOver() {
        player.removeFromParent()
        dead.alpha = 1
        restartLabel.alpha = 1
        gameState = .dead
        speed = 0
        let deathSound = SKAction.playSoundFileNamed("death.mp3", waitForCompletion: false)
        run(deathSound)
        backgroundMusic.run(SKAction.stop())

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
    }
    
    
    
   
    
    override func didMove(to view: SKView) {
        createPlayer()
        createDirt()
        createWalls()
//        startRocks()
        createScore()
        createScreens()
        
        motionManager.startAccelerometerUpdates()
        
        physicsWorld.contactDelegate = self
        
        if let musicURL = Bundle.main.url(forResource: "music", withExtension: "m4a") {
            backgroundMusic = SKAudioNode(url: musicURL)
            addChild(backgroundMusic)
            backgroundMusic.run(SKAction.changeVolume(to: Float(0.15), duration: 0))
        }
        
        

    }
    
    
    override func update(_ currentTime: TimeInterval) {
    // Called before each frame is rendered
        guard player != nil else { return }
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame.inset(by: UIEdgeInsets(top: 700, left: 0, bottom: 400, right: 0)))
        if let accelerometerData = motionManager.accelerometerData {
            physicsWorld.gravity = CGVector(dx: accelerometerData.acceleration.x * tiltSensitivity, dy: accelerometerData.acceleration.y * tiltSensitivity)
        }
        
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        if contact.bodyA.node?.name == "detectScore" || contact.bodyB.node?.name == "detectScore" {
            if contact.bodyA.node == player {
                contact.bodyB.node?.removeFromParent()
            } else {
                contact.bodyA.node?.removeFromParent()
            }
            let successSound = SKAction.playSoundFileNamed("success.mp3", waitForCompletion: false)
            run(successSound)
            score += 1
            
          
            if score <= 20 {
                tiltSensitivity += 1.75
            } else if score > 20 && score < 40 {
                tiltSensitivity = Double.random(in: 20...65)
            } else {
                tiltSensitivity = Double.random(in: 5...100)
            }
            return
        }
        guard contact.bodyA.node != nil && contact.bodyB.node != nil else {
                return
            }
        
        if contact.bodyA.node?.name == "rightWall" || contact.bodyB.node?.name == "rightWall" {
            gameOver()
        }
        
        if contact.bodyA.node?.name == "leftWall" || contact.bodyB.node?.name == "leftWall" {
            gameOver()
        }
        
        if contact.bodyA.node?.name == "leftRock" || contact.bodyB.node?.name == "leftRock" {
            gameOver()
        }
        
        if contact.bodyA.node?.name == "rightRock" || contact.bodyB.node?.name == "rightRock" {
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
                       self.startRocks()
                   }
            
            let sequence = SKAction.sequence([fadeOut, wait, activatePlayer, remove])
                  title.run(sequence)
        case .playing:
            // power up stuff here
            //        player.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
            //        player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 20))

            break
        case .dead:
            if let scene = GameScene(fileNamed: "GameScene") {
                scene.scaleMode = .aspectFill
                let transition = SKTransition.moveIn(with: SKTransitionDirection.down, duration: 1)
                view?.presentScene(scene, transition: transition)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {

    }
}
