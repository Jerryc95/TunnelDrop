//
//  Challenges.swift
//  TunnelDrop
//
//  Daily challenges: three per day, generated deterministically from the
//  date so every player gets the same set. Progress accrues across runs,
//  rewards are claimed manually, and consecutive claim-days build a
//  7-day streak with a bonus on day 7.
//

import SwiftUI

struct DailyChallenge: Codable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case scoreInOneRun
        case earnCoins
        case useFlutter
        case passGates
    }

    let kind: Kind
    let target: Int
    let reward: Int
    var progress = 0
    var claimed = false

    var id: String { kind.rawValue }
    var isComplete: Bool { progress >= target }

    var title: String {
        switch kind {
        case .scoreInOneRun: return "Score \(target) in one run"
        case .earnCoins: return "Earn \(target) coins"
        case .useFlutter: return "Use flutter \(target) times"
        case .passGates: return "Pass \(target) spikes"
        }
    }

    var emoji: String {
        switch kind {
        case .scoreInOneRun: return "🚩"
        case .earnCoins: return "🪙"
        case .useFlutter: return "⚡️"
        case .passGates: return "🪨"
        }
    }

    var barColor: Color {
        switch kind {
        case .scoreInOneRun: return .blue
        case .earnCoins: return Theme.gold
        case .useFlutter: return Theme.orange
        case .passGates: return .purple
        }
    }
}

final class DailyChallengeStore: ObservableObject {
    static let shared = DailyChallengeStore()

    @Published private(set) var challenges: [DailyChallenge] = []
    @Published private(set) var streak = 0

    static let streakLength = 7
    static let streakBonus = 200

    private let defaults = UserDefaults.standard

    init() {
        refreshForToday()
    }

    func refreshForToday() {
        let today = Self.dayString(Date())
        streak = defaults.integer(forKey: "dailyStreak")

        if defaults.string(forKey: "dailyDate") == today,
           let data = defaults.data(forKey: "dailyChallenges"),
           let saved = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            challenges = saved
            return
        }

        // New day: a missed claim-day breaks the streak.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let lastClaim = defaults.string(forKey: "lastClaimDay")
        if lastClaim != today && lastClaim != Self.dayString(yesterday) {
            streak = 0
            defaults.set(0, forKey: "dailyStreak")
        }

        challenges = Self.generate(for: Date())
        defaults.set(today, forKey: "dailyDate")
        save()
    }

    func recordRun(score: Int, coins: Int, flutterUses: Int, gates: Int) {
        refreshForToday()
        for index in challenges.indices where !challenges[index].claimed {
            switch challenges[index].kind {
            case .scoreInOneRun:
                challenges[index].progress = max(challenges[index].progress, score)
            case .earnCoins:
                challenges[index].progress += coins
            case .useFlutter:
                challenges[index].progress += flutterUses
            case .passGates:
                challenges[index].progress += gates
            }
        }
        save()
    }

    func claim(_ id: String) {
        guard let index = challenges.firstIndex(where: { $0.id == id }),
              challenges[index].isComplete,
              !challenges[index].claimed else { return }

        challenges[index].claimed = true
        var payout = challenges[index].reward

        let today = Self.dayString(Date())
        if defaults.string(forKey: "lastClaimDay") != today {
            defaults.set(today, forKey: "lastClaimDay")
            streak += 1
            if streak >= Self.streakLength {
                payout += Self.streakBonus
                streak = 0
            }
            defaults.set(streak, forKey: "dailyStreak")
        }

        defaults.set(defaults.integer(forKey: "coinBalance") + payout, forKey: "coinBalance")
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(challenges) {
            defaults.set(data, forKey: "dailyChallenges")
        }
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // Deterministic per-date generation: same three challenges for everyone.
    static func generate(for date: Date) -> [DailyChallenge] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var seed = UInt64(components.year! * 10000 + components.month! * 100 + components.day!)
        func next(_ bound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 33) % UInt64(bound))
        }

        var kinds = DailyChallenge.Kind.allCases
        var picked: [DailyChallenge.Kind] = []
        for _ in 0..<3 {
            picked.append(kinds.remove(at: next(kinds.count)))
        }

        return picked.map { kind in
            switch kind {
            case .scoreInOneRun:
                let targets = [50, 75, 100, 150]
                let target = targets[next(targets.count)]
                return DailyChallenge(kind: kind, target: target, reward: target)
            case .earnCoins:
                let targets = [5, 10, 15]
                let target = targets[next(targets.count)]
                return DailyChallenge(kind: kind, target: target, reward: target * 8)
            case .useFlutter:
                let targets = [10, 20, 30]
                let target = targets[next(targets.count)]
                return DailyChallenge(kind: kind, target: target, reward: 50)
            case .passGates:
                let targets = [40, 80, 120]
                let target = targets[next(targets.count)]
                return DailyChallenge(kind: kind, target: target, reward: target / 2 + 25)
            }
        }
    }
}

// MARK: - UI

struct DailyView: View {
    @ObservedObject private var store = DailyChallengeStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Daily")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    countdownPill
                }

                streakCard

                Text("TODAY'S CHALLENGES")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .kerning(2)

                ForEach(store.challenges) { challenge in
                    challengeRow(challenge)
                }
            }
            .padding(22)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { store.refreshForToday() }
    }

    private var countdownPill: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let midnight = Calendar.current.startOfDay(for: context.date.addingTimeInterval(86400))
            let remaining = max(0, Int(midnight.timeIntervalSince(context.date)))
            Label(
                String(format: "%02d:%02d:%02d", remaining / 3600, remaining / 60 % 60, remaining % 60),
                systemImage: "clock"
            )
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.pill, in: Capsule())
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔥 \(DailyChallengeStore.streakLength) Day Streak")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("Day \(min(store.streak + 1, DailyChallengeStore.streakLength)) of \(DailyChallengeStore.streakLength)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(1...DailyChallengeStore.streakLength, id: \.self) { day in
                    streakChip(day)
                }
            }
        }
        .padding(16)
        .background(Theme.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.orange.opacity(0.35), lineWidth: 1.5)
        )
    }

    private func streakChip(_ day: Int) -> some View {
        let reached = day <= store.streak
        return Group {
            if day == DailyChallengeStore.streakLength && !reached {
                Text("🎁")
            } else {
                Text("\(day)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(reached ? .black : .white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(reached ? Theme.orange : Theme.pill, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(day == store.streak + 1 ? Theme.gold : .clear, lineWidth: 2)
        )
    }

    private func challengeRow(_ challenge: DailyChallenge) -> some View {
        HStack(spacing: 14) {
            Text(challenge.emoji)
                .font(.system(size: 24))
                .frame(width: 52, height: 52)
                .background(challenge.barColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 7) {
                Text(challenge.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.pill)
                        Capsule()
                            .fill(challenge.isComplete ? Theme.green : challenge.barColor)
                            .frame(width: geometry.size.width * min(1, CGFloat(challenge.progress) / CGFloat(challenge.target)))
                    }
                }
                .frame(height: 8)

                Text("\(min(challenge.progress, challenge.target)) / \(challenge.target)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if challenge.claimed {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.green)
            } else if challenge.isComplete {
                Button {
                    store.claim(challenge.id)
                } label: {
                    Text("CLAIM")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Theme.green, in: Capsule())
                }
            } else {
                VStack(spacing: 2) {
                    Text("🪙")
                    Text("+\(challenge.reward)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(challenge.isComplete && !challenge.claimed ? Theme.green.opacity(0.6) : .clear, lineWidth: 1.5)
        )
    }
}
