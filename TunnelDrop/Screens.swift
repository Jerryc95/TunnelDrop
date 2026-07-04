//
//  Screens.swift
//  TunnelDrop
//
//  SwiftUI surfaces layered over the SpriteKit view: home, game over,
//  and placeholder sheets for shop/ranks/daily.
//

import SwiftUI

enum Theme {
    static let background = Color(red: 0.14, green: 0.10, blue: 0.08)
    static let card = Color(red: 0.21, green: 0.16, blue: 0.13)
    static let pill = Color(red: 0.11, green: 0.08, blue: 0.06)
    static let pillEdge = Color(red: 0.05, green: 0.035, blue: 0.025)
    static let orange = Color(red: 0.96, green: 0.57, blue: 0.24)
    static let orangeEdge = Color(red: 0.70, green: 0.37, blue: 0.12)
    static let gold = Color(red: 0.94, green: 0.71, blue: 0.16)
    static let green = Color(red: 0.30, green: 0.79, blue: 0.39)
    static let greenEdge = Color(red: 0.16, green: 0.52, blue: 0.24)
}

// Chunky "game button": raised face over a darker bottom edge; the face
// drops onto the edge while pressed.
struct ChunkyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var color: Color
    var edge: Color
    var cornerRadius: CGFloat = 14
    var verticalPadding: CGFloat = 12
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, fullWidth ? 0 : 18)
            .background(RoundedRectangle(cornerRadius: cornerRadius).fill(color))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(edge)
                    .offset(y: 4)
            )
            // Flatten before dimming so the edge layer can't show through
            // a translucent face when disabled.
            .compositingGroup()
            .opacity(isEnabled ? 1 : 0.5)
    }
}

final class GameFlow: ObservableObject {
    enum Screen {
        case home
        case playing
        case gameOver(GameResult)
    }

    @Published var screen = Screen.home

    // Wired up by GameViewController.
    var onPlay: (() -> Void)?
    var onRetry: (() -> Void)?
    var onHome: (() -> Void)?
}

struct RootOverlayView: View {
    @ObservedObject var flow: GameFlow

    var body: some View {
        switch flow.screen {
        case .home:
            HomeView(flow: flow)
        case .playing:
            Color.clear
        case .gameOver(let result):
            GameOverView(result: result, flow: flow)
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var flow: GameFlow
    @AppStorage("coinBalance") private var coinBalance = 0
    @AppStorage("highScore") private var highScore = 0
    @AppStorage("equippedSkin") private var equippedSkin = "classic"
    @State private var sheet: SheetKind?

    enum SheetKind: String, Identifiable {
        case shop = "Shop"
        case ranks = "Ranks"
        case daily = "Daily"
        case more = "More"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    sheet = .shop
                } label: {
                    HStack(spacing: 6) {
                        Text("🪙 \(coinBalance)")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                        Image(systemName: "plus.circle.fill")
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.pill, in: Capsule())
                }
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: -6) {
                Text("TUNNEL")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.gold)
                Text("DROP")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.orange)
            }

            Image("player-1")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .colorMultiply((Skin.all.first { $0.id == equippedSkin } ?? Skin.all[0]).previewColor)
                .padding(28)
                .background(Theme.card, in: Circle())
                .padding(.top, 28)

            HStack(spacing: 8) {
                Text("🏆")
                Text("BEST")
                    .foregroundStyle(.secondary)
                Text("\(highScore)")
            }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Theme.pill, in: Capsule())
            .padding(.top, 22)

            Spacer()

            Button {
                flow.onPlay?()
            } label: {
                Label("PLAY", systemImage: "play.fill")
                    .font(.system(size: 26, weight: .black, design: .rounded))
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.orange, edge: Theme.orangeEdge, cornerRadius: 22, verticalPadding: 20))

            HStack(spacing: 10) {
                navButton("SHOP", emoji: "🏪") { sheet = .shop }
                navButton("RANKS", emoji: "🏆") { sheet = .ranks }
                navButton("DAILY", emoji: "🔥") { sheet = .daily }
                navButton("MORE", emoji: "⚙️") { sheet = .more }
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $sheet) { kind in
            switch kind {
            case .shop:
                ShopView()
            case .daily:
                DailyView()
            default:
                ComingSoonView(title: kind.rawValue)
            }
        }
    }

    private func navButton(_ label: String, emoji: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 24))
                Text(label)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Game over

struct GameOverView: View {
    let result: GameResult
    @ObservedObject var flow: GameFlow

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                if result.isNewBest {
                    Text("⭐️ NEW BEST!")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Theme.gold, in: Capsule())
                }

                Text("SCORE")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .kerning(3)
                    .padding(.top, 4)
                Text("\(result.score)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    statTile(title: "PREV BEST", value: "\(result.previousBest)", highlight: false)
                    statTile(title: "EARNED", value: "🪙 +\(result.coinsEarned)", highlight: true)
                }

                Button {
                    flow.onRetry?()
                } label: {
                    Label("RETRY", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.orange, edge: Theme.orangeEdge, cornerRadius: 18, verticalPadding: 16))
                .padding(.top, 10)

                Button {
                    flow.onHome?()
                } label: {
                    Label("HOME", systemImage: "house.fill")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.pill, edge: Theme.pillEdge, cornerRadius: 18, verticalPadding: 16))

                ShareLink(item: "I scored \(result.score) in Tunnel Drop! Can you beat it? 🐦") {
                    Label("SHARE SCORE", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            .padding(24)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 26)
        }
    }

    private func statTile(title: String, value: String, highlight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .kerning(1.5)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(highlight ? Theme.gold : .white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.pill, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlight ? Theme.gold.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Placeholder

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Coming soon")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
