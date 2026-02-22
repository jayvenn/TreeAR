//
//  ContentView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SwiftUI

/// Root SwiftUI view.
///
/// Observes `AppCoordinator` and reacts to navigation events:
/// - Presents the intro screen initially.
/// - Presents the AR experience full-screen when the coordinator fires.
struct ContentView: View {

    /// `@Bindable` (iOS 17+) lets us derive `$coordinator.showARExperience`
    /// from an `@Observable` object without `ObservableObject` or `@Published`.
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        IntroductionViewRepresentable(
            viewModel: IntroductionViewModel(coordinator: coordinator)
        )
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $coordinator.showARExperience) {
            ARViewRepresentable(onDismiss: { coordinator.showARExperience = false })
                .ignoresSafeArea()
        }
    }
}

// MARK: - UIViewControllerRepresentable bridges

struct IntroductionViewRepresentable: UIViewControllerRepresentable {
    let viewModel: IntroductionViewModel

    func makeUIViewController(context: Context) -> IntroductionViewController {
        let vc = IntroductionViewController()
        vc.viewModel = viewModel
        return vc
    }

    func updateUIViewController(_ uiViewController: IntroductionViewController, context: Context) {}
}

struct ARViewRepresentable: UIViewControllerRepresentable {
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> ARViewController {
        let audioService  = AudioService()
        let sceneDirector = ARSceneDirector()
        let viewModel     = ARExperienceViewModel(sceneDirector: sceneDirector,
                                                  audioService: audioService)
        let vc = ARViewController(viewModel: viewModel)
        vc.onDismiss = onDismiss
        return vc
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ContentView(coordinator: AppCoordinator())
}
