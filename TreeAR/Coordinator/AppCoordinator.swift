//
//  AppCoordinator.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Manages top-level navigation for the app.
///
/// In MVVM-C, the **Coordinator** owns the screen-to-screen flow.
/// ViewModels call coordinator methods instead of making navigation
/// decisions themselves — keeping ViewModels testable and screen-agnostic.
///
/// `AppCoordinator` is an `ObservableObject` so SwiftUI's `ContentView`
/// can reactively present the AR experience when `showARExperience` flips.
final class AppCoordinator: ObservableObject {

    /// Set to `true` to push the full-screen AR experience.
    @Published private(set) var showARExperience = false

    // MARK: - Navigation actions

    /// Called by `IntroductionViewModel` when the user confirms they are ready.
    func startARExperience() {
        showARExperience = true
    }
}
