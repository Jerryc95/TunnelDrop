//
//  GameCenter.swift
//  TunnelDrop
//
//  Game Center authentication, score submission, and the leaderboard UI.
//

import GameKit

final class GameCenterManager: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterManager()

    // Must match the leaderboard ID configured in App Store Connect.
    static let bestScoreLeaderboardID = "com.jerrycox.TunnelDrop.best"

    private(set) var isAuthenticated = false

    func authenticate(presenting viewController: UIViewController) {
        GKLocalPlayer.local.authenticateHandler = { [weak self, weak viewController] loginViewController, _ in
            if let loginViewController, let viewController {
                viewController.present(loginViewController, animated: true)
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    func submit(score: Int) {
        guard isAuthenticated, score > 0 else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [Self.bestScoreLeaderboardID]) { _ in }
    }

    func showLeaderboard(from viewController: UIViewController) {
        guard isAuthenticated else {
            // Re-trigger the login sheet if the player skipped it earlier.
            authenticate(presenting: viewController)
            return
        }
        let gameCenterViewController = GKGameCenterViewController(leaderboardID: Self.bestScoreLeaderboardID, playerScope: .global, timeScope: .allTime)
        gameCenterViewController.gameCenterDelegate = self
        viewController.present(gameCenterViewController, animated: true)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
