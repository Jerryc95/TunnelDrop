//
//  Coins.swift
//  TunnelDrop
//
//  Persistent coin balance, earned at the end of each run from score.
//

import SpriteKit

extension GameScene {

    func createCoinHUD() {
        coinLabel = SKLabelNode(fontNamed: "MarkerFelt-Wide")
        coinLabel.fontSize = 30
        coinLabel.horizontalAlignmentMode = .right
        coinLabel.position = CGPoint(x: frame.maxX - hudInsetX - 30, y: hudTopY - 30)
        coinLabel.fontColor = UIColor.white
        coinLabel.zPosition = 90
        coinLabel.text = "🪙 \(coinBalance)"
        addChild(coinLabel)
    }
}
