//
//  ARExperienceState.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

/// Each case represents one exclusive phase of the AR adventure.
/// UI metadata is co-located here so the ViewController needs zero conditional logic.
enum ARExperienceState: Equatable {
    case idle
    case scanning
    case awaitingGrassTap
    case bossSpawning
    case combatActive
    case bossDefeated
    case spiritChase
    case playerDefeated
    case victory
}

extension ARExperienceState {

    var instructionText: String? {
        switch self {
        case .scanning:         return "MOVE AROUND"
        case .awaitingGrassTap: return "TAP THE GRASS"
        default:                return nil
        }
    }

    var showsScanningOverlay: Bool { self == .scanning }

    var tappableNodeNames: Set<String> {
        switch self {
        case .awaitingGrassTap: return ["grass"]
        default:                return []
        }
    }

    var showsCombatHUD: Bool {
        switch self {
        case .combatActive, .bossDefeated, .spiritChase, .playerDefeated, .victory: return true
        default: return false
        }
    }

    var acceptsCombatTaps: Bool { self == .combatActive }
}
