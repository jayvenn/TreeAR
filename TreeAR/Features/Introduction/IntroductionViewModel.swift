//
//  IntroductionViewModel.swift
//  TreeAR
//
//  ViewModel for the introduction screen. Handles user intent and delegates navigation to the coordinator.
//

import Foundation

final class IntroductionViewModel {
    
    private let coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    func beginTapped() {
        coordinator.showAR()
    }
}
