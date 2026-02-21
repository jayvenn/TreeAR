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

    /// Idle duration range between attacks narrows in later phases.
    var idleDurationRange: ClosedRange<TimeInterval> {
        switch self {
        case .phase1: return 2.2...3.0
        case .phase2: return 1.5...2.3
        case .phase3: return 1.0...1.8
        }
    }
}
