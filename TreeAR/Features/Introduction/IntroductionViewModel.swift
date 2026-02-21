//
//  IntroductionViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Presentation logic for the introduction screen.
///
/// The ViewModel delegates all navigation decisions to `AppCoordinator`,
/// keeping screen-to-screen routing out of the ViewController and the ViewModel.
final class IntroductionViewModel {

    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func beginTapped() {
        coordinator?.startARExperience()
    }
}
