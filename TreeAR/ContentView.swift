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

    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        IntroductionViewRepresentable(
            viewModel: IntroductionViewModel(coordinator: coordinator)
        )
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $coordinator.showARExperience) {
            ARViewRepresentable()
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
    /// Composition root: all concrete service types are constructed here,
    /// keeping every ViewController and ViewModel free of direct dependencies.
    func makeUIViewController(context: Context) -> ARViewController {
        let audioService  = AudioService()
        let sceneDirector = ARSceneDirector()
        let viewModel     = ARExperienceViewModel(sceneDirector: sceneDirector,
                                                  audioService: audioService)
        return ARViewController(viewModel: viewModel)
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ContentView(coordinator: AppCoordinator())
}
