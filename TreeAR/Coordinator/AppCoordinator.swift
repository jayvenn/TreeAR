//
//  AppCoordinator.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Observation

/// Manages top-level navigation for the app.
///
/// In MVVM-C, the **Coordinator** owns the screen-to-screen flow.
/// ViewModels call coordinator methods instead of making navigation
/// decisions themselves — keeping ViewModels testable and screen-agnostic.
///
/// `@Observable` (iOS 17+) gives SwiftUI fine-grained dependency tracking
/// with no need for `ObservableObject` or `@Published`.
@Observable
final class AppCoordinator {

    /// Set to `true` to push the full-screen AR experience.
    /// Internal setter required for SwiftUI `@Bindable` two-way binding.
    var showARExperience = false

    // MARK: - Navigation actions

    /// Called by `IntroductionViewModel` when the user confirms they are ready.
    func startARExperience() {
        showARExperience = true
    }
}
