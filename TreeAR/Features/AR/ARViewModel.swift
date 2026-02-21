//
//  ARViewModel.swift
//  TreeAR
//
//  ViewModel for the AR experience. Holds game state and delegates navigation to the coordinator.
//  SceneKit/ARKit-specific logic remains in ARViewController (presentation layer).
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
