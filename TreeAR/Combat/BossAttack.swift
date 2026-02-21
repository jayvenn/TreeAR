//
//  BossAttack.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Every distinct attack the boss can perform, with all timing and geometry baked in.
enum BossAttack: CaseIterable, Equatable {
    case groundSlam
    case sweep
    case stompWave
    case enragedCombo
}

extension BossAttack {

    /// Seconds the telegraph indicator is visible before the attack executes.
    var telegraphDuration: TimeInterval {
        switch self {
        case .groundSlam:    return 1.5
        case .sweep:         return 1.2
        case .stompWave:     return 1.5
        case .enragedCombo:  return 2.0
        }
    }

    /// Seconds the attack animation plays.
    var executeDuration: TimeInterval {
        switch self {
        case .groundSlam:    return 0.6
        case .sweep:         return 0.8
        case .stompWave:     return 0.5
        case .enragedCombo:  return 1.5
        }
    }

    /// Seconds the boss is vulnerable after the attack.
    var recoveryDuration: TimeInterval {
        switch self {
        case .groundSlam:    return 1.2
        case .sweep:         return 1.0
        case .stompWave:     return 0.8
        case .enragedCombo:  return 1.5
        }
    }

    /// Horizontal distance (meters) from boss center within which the player takes damage.
    var threatRadius: Float {
        switch self {
        case .groundSlam:    return 2.0
        case .sweep:         return 2.5
        case .stompWave:     return 3.0
        case .enragedCombo:  return 2.5
        }
    }

    /// HP removed from the player if the attack connects.
    var damage: Int {
        switch self {
        case .groundSlam:    return 30
        case .sweep:         return 20
        case .stompWave:     return 25
        case .enragedCombo:  return 50
        }
    }

    /// Total time from telegraph start to recovery end — one full attack cycle.
    var totalCycleDuration: TimeInterval {
        telegraphDuration + executeDuration + recoveryDuration
    }

    /// The minimum boss phase required to unlock this attack.
    var minimumPhase: BossPhase {
        switch self {
        case .groundSlam, .sweep:   return .phase1
        case .stompWave:            return .phase2
        case .enragedCombo:         return .phase3
        }
    }

    /// Whether this attack only hits the frontal 180° arc (vs full 360°).
    var isFrontalOnly: Bool { self == .sweep }
}
