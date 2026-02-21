//
//  ARViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation
import SceneKit

final class ARViewModel {
    
    private let coordinator: AppCoordinator
    
    private(set) var foundSurface = false
    private(set) var gameStarted = false
    private(set) var gamePosition = SCNVector3(0, 0, 0)
    
    var canPlantSeed: Bool { foundSurface && !gameStarted }
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    func surfaceFound(at position: SCNVector3) {
        foundSurface = true
    }
    
    /// Call with the computed game position (after applying holeNodeYAllevation).
    /// Returns true if planting was allowed.
    func plantSeed(at computedPosition: SCNVector3) -> Bool {
        guard canPlantSeed else { return false }
        gameStarted = true
        gamePosition = computedPosition
        return true
    }
    
    func dismiss() {
        coordinator.dismissAR()
    }
}
