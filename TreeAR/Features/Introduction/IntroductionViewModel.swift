//
//  IntroductionViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
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
