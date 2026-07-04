//
//  GameViewController.swift
//  TunnelDrop
//
//  Created by Jerry Cox on 2/3/24.
//

import UIKit
import SpriteKit
import SwiftUI

class GameViewController: UIViewController {

    private let flow = GameFlow()
    private var hostingController: UIHostingController<RootOverlayView>!
    private var currentScene: GameScene?

    private var skView: SKView { view as! SKView }

    override func viewDidLoad() {
        super.viewDidLoad()

        skView.ignoresSiblingOrder = true
//        skView.showsFPS = true
//        skView.showsNodeCount = true
//        skView.showsPhysics = true

        presentScene()

        flow.onPlay = { [weak self] in self?.startRun() }
        flow.onRetry = { [weak self] in
            self?.currentScene?.finalizeRun()
            self?.startRun()
        }
        flow.onHome = { [weak self] in
            self?.currentScene?.finalizeRun()
            self?.goHome()
        }
        flow.onRevive = { [weak self] in self?.revive() }

        hostingController = UIHostingController(rootView: RootOverlayView(flow: flow))
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    // Each run gets a fresh scene; the previous one is discarded wholesale.
    @discardableResult
    private func presentScene() -> GameScene? {
        guard let scene = GameScene(fileNamed: "GameScene") else { return nil }
        scene.scaleMode = .aspectFill
        scene.onGameOver = { [weak self] result in
            guard let self else { return }
            self.flow.screen = .gameOver(result)
            self.hostingController.view.isUserInteractionEnabled = true
        }
        skView.presentScene(scene)
        currentScene = scene
        return scene
    }

    private func revive() {
        guard let scene = currentScene else { return }
        let defaults = UserDefaults.standard
        let stock = defaults.integer(forKey: "reviveStock")
        if stock > 0 {
            defaults.set(stock - 1, forKey: "reviveStock")
        } else {
            let balance = defaults.integer(forKey: "coinBalance")
            guard balance >= GameFlow.revivePrice else { return }
            defaults.set(balance - GameFlow.revivePrice, forKey: "coinBalance")
        }
        flow.screen = .playing
        hostingController.view.isUserInteractionEnabled = false
        scene.reviveFromGameOver()
    }

    private func startRun() {
        guard let scene = presentScene() else { return }
        flow.screen = .playing
        hostingController.view.isUserInteractionEnabled = false
        scene.startRun()
    }

    private func goHome() {
        presentScene()
        flow.screen = .home
        hostingController.view.isUserInteractionEnabled = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
