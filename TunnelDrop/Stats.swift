//
//  Stats.swift
//  TunnelDrop
//
//  Per-run stats reporting, lifetime stat accumulation, and one-time
//  achievements with coin rewards.
//

import SwiftUI

struct RunStats {
    let score: Int
    let coins: Int
    let meters: Double
    let feathers: Int
    let ghostUses: Int
    let powerUps: Int
    let zoneReached: Int
    let nearMisses: Int
    let flutterUses: Int
}

enum LifetimeStats {
    static func record(_ stats: RunStats) {
        let defaults = UserDefaults.standard
        defaults.set(defaults.double(forKey: "lifeMeters") + stats.meters, forKey: "lifeMeters")
        defaults.set(defaults.integer(forKey: "lifeNearMisses") + stats.nearMisses, forKey: "lifeNearMisses")
        defaults.set(defaults.integer(forKey: "lifeRuns") + 1, forKey: "lifeRuns")
        defaults.set(defaults.integer(forKey: "lifePowerUps") + stats.powerUps, forKey: "lifePowerUps")
        if stats.zoneReached > defaults.integer(forKey: "lifeMaxZone") {
            defaults.set(stats.zoneReached, forKey: "lifeMaxZone")
        }
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let reward: Int
    let target: Int
    let progress: () -> Int

    var isComplete: Bool { progress() >= target }

    static let all: [Achievement] = {
        let defaults = UserDefaults.standard
        return [
            Achievement(id: "fall1k", title: "Fall 1,000m lifetime", emoji: "⬇️", reward: 100, target: 1000) {
                Int(defaults.double(forKey: "lifeMeters"))
            },
            Achievement(id: "fall10k", title: "Fall 10,000m lifetime", emoji: "🕳️", reward: 500, target: 10000) {
                Int(defaults.double(forKey: "lifeMeters"))
            },
            Achievement(id: "firstPowerUp", title: "Collect first power-up", emoji: "⭐️", reward: 50, target: 1) {
                defaults.integer(forKey: "lifePowerUps")
            },
            Achievement(id: "clearZone1", title: "Clear first zone", emoji: "🗺️", reward: 75, target: 2) {
                defaults.integer(forKey: "lifeMaxZone")
            },
            Achievement(id: "reachZone3", title: "Reach zone 3", emoji: "🌋", reward: 200, target: 3) {
                defaults.integer(forKey: "lifeMaxZone")
            },
            Achievement(id: "reachZone5", title: "Reach zone 5", emoji: "🏆", reward: 500, target: 5) {
                defaults.integer(forKey: "lifeMaxZone")
            },
            Achievement(id: "nearMiss100", title: "Get 100 near misses", emoji: "😬", reward: 150, target: 100) {
                defaults.integer(forKey: "lifeNearMisses")
            },
            Achievement(id: "runs50", title: "Play 50 runs", emoji: "🎮", reward: 200, target: 50) {
                defaults.integer(forKey: "lifeRuns")
            },
            Achievement(id: "runs500", title: "Play 500 runs", emoji: "👑", reward: 1000, target: 500) {
                defaults.integer(forKey: "lifeRuns")
            },
            Achievement(id: "firstSkin", title: "Unlock first skin", emoji: "🐦", reward: 100, target: 1) {
                let owned = defaults.string(forKey: "ownedSkins") ?? "classic"
                return max(0, owned.split(separator: ",").filter { $0 != "classic" }.count)
            },
        ]
    }()

    private init(id: String, title: String, emoji: String, reward: Int, target: Int, progress: @escaping () -> Int) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.reward = reward
        self.target = target
        self.progress = progress
    }
}

struct AchievementsSection: View {
    @AppStorage("claimedAchievements") private var claimedRaw = ""
    @AppStorage("coinBalance") private var coinBalance = 0

    private var claimed: Set<String> {
        Set(claimedRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        ForEach(Achievement.all) { achievement in
            row(achievement)
        }
    }

    private func row(_ achievement: Achievement) -> some View {
        let progress = achievement.progress()
        let isClaimed = claimed.contains(achievement.id)

        return HStack(spacing: 14) {
            Text(achievement.emoji)
                .font(.system(size: 24))
                .frame(width: 52, height: 52)
                .background(Theme.pill, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 7) {
                Text(achievement.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.pill)
                        Capsule()
                            .fill(achievement.isComplete ? Theme.green : Theme.orange)
                            .frame(width: geometry.size.width * min(1, CGFloat(progress) / CGFloat(achievement.target)))
                    }
                }
                .frame(height: 8)

                Text("\(min(progress, achievement.target)) / \(achievement.target)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if isClaimed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.green)
            } else if achievement.isComplete {
                Button {
                    claimedRaw += ",\(achievement.id)"
                    coinBalance += achievement.reward
                } label: {
                    Text("CLAIM")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.green, edge: Theme.greenEdge, cornerRadius: 12, verticalPadding: 10, fullWidth: false))
            } else {
                VStack(spacing: 2) {
                    Text("🪙")
                    Text("+\(achievement.reward)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
    }
}
