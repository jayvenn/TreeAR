//
//  BossPhase.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Boss difficulty phase, escalating as HP drops.
enum BossPhase: Int, Comparable {
    case phase1 = 1  // 100%–60% HP
    case phase2 = 2  // 60%–30% HP
    case phase3 = 3  // 30%–0% HP (enrage)

    static func < (lhs: BossPhase, rhs: BossPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var idleDurationRange: ClosedRange<TimeInterval> {
        switch self {
        case .phase1: return 1.4...2.0
        case .phase2: return 0.9...1.4
        case .phase3: return 0.5...0.9
        }
    }

    /// Walk speed (meters/second) when chasing the player.
    var moveSpeed: Float {
        switch self {
        case .phase1: return 1.0
        case .phase2: return 1.4
        case .phase3: return 1.8
        }
    }

    /// The boss tries to close to this distance before attacking.
    var engagementRange: Float {
        switch self {
        case .phase1: return 1.8
        case .phase2: return 1.6
        case .phase3: return 1.4
        }
    }
}
