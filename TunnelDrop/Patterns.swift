//
//  Patterns.swift
//  TunnelDrop
//
//  Authored spike-gap patterns so runs are learnable instead of purely random.
//

import SpriteKit

struct SpikePattern {
    let name: String
    // Gap positions across the tunnel: 0 = far left, 1 = far right.
    let gapPositions: [CGFloat]

    static let all: [SpikePattern] = [
        SpikePattern(name: "zigzag", gapPositions: [0.15, 0.85, 0.15, 0.85]),
        SpikePattern(name: "slalom", gapPositions: [0.35, 0.65, 0.35, 0.65]),
        SpikePattern(name: "sweepRight", gapPositions: [0.1, 0.3, 0.5, 0.7, 0.9]),
        SpikePattern(name: "sweepLeft", gapPositions: [0.9, 0.7, 0.5, 0.3, 0.1]),
        SpikePattern(name: "centerHold", gapPositions: [0.5, 0.5, 0.5]),
        SpikePattern(name: "edges", gapPositions: [0.1, 0.9, 0.1]),
        SpikePattern(name: "vee", gapPositions: [0.8, 0.5, 0.2, 0.5, 0.8]),
    ]
}

extension GameScene {

    // Pulls the next gap from the running pattern, drawing a fresh random
    // pattern (plus an occasional random breather gap) when one finishes.
    func nextGapPosition() -> CGFloat {
        if patternQueue.isEmpty {
            var gaps = SpikePattern.all.randomElement()!.gapPositions
            if Bool.random() {
                gaps.append(CGFloat.random(in: 0.1...0.9))
            }
            patternQueue = gaps
        }
        return patternQueue.removeFirst()
    }

    // Maps a 0...1 gap fraction to a screen x, keeping the full gap width
    // clear of the side walls.
    func gapCenterX(for fraction: CGFloat) -> CGFloat {
        let wallInset: CGFloat = 90
        let halfGap: CGFloat = 100
        let minCenter = wallInset + halfGap + 20
        let maxCenter = frame.width - wallInset - halfGap - 20
        return minCenter + (maxCenter - minCenter) * fraction
    }
}
