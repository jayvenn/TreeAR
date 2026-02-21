//
//  ARExperienceState.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

/// Each case represents one exclusive phase of the AR adventure.
/// UI metadata is co-located here so the ViewController needs zero conditional logic
/// — it simply reads the properties of whatever state it receives.
enum ARExperienceState: Equatable {
    /// App just launched, coordinator not yet started.
    case idle
    /// ARKit is scanning for a horizontal surface. Scanning overlay visible.
    case scanning
    /// Grass has grown; user can tap it.
    case awaitingGrassTap
    /// Grass is shrinking and the magic box is animating in. No user input.
    case boxPresenting
    /// Box is visible but the tap-hint has not yet appeared.
    case awaitingBoxTap
    /// Box is visible and the "TAP ON THE BOX" hint is showing.
    case awaitingBoxTapHinted
    /// Box is opening. No user input accepted.
    case boxOpening
    /// Guardian is rising, speaking, then lowering.
    case guardianPresenting
    /// Guardian has returned — the experience is complete.
    case complete
}

// MARK: - UI Metadata

extension ARExperienceState {

    /// Instruction text to display immediately on entering this state.
    /// `nil` means the label should be hidden (fade-out handled by the VC).
    var instructionText: String? {
        switch self {
        case .scanning:           return "MOVE AROUND TO\nSEE WHAT YOU CAN FIND!"
        case .awaitingGrassTap:   return "TAP ON THE GRASS\nTO SEE WHAT'S AROUND."
        case .awaitingBoxTapHinted: return "TAP ON THE BOX\nTO OPEN UP THE BOX."
        default:                  return nil
        }
    }

    /// Whether the surface-scanning overlay should be visible.
    var showsScanningOverlay: Bool { self == .scanning }

    /// Node names whose taps should be forwarded to the coordinator in this state.
    /// An empty set means taps are silently ignored.
    var tappableNodeNames: Set<String> {
        switch self {
        case .awaitingGrassTap:                          return ["grass"]
        case .awaitingBoxTap, .awaitingBoxTapHinted:     return ["base", "cover"]
        default:                                         return []
        }
    }
}
