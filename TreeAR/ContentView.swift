//
//  ContentView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SwiftUI

struct ContentView: View {
    @State private var showAR = false

    var body: some View {
        IntroductionViewRepresentable(
            viewModel: IntroductionViewModel { showAR = true }
        )
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showAR) {
            ARViewRepresentable()
                .ignoresSafeArea()
        }
    }
}

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
    func makeUIViewController(context: Context) -> ARViewController {
        // Composition root: build the dependency graph here, keeping
        // all concrete types out of the ViewController and SwiftUI layer.
        let audioService  = AudioService()
        let sceneDirector = ARSceneDirector()
        let coordinator   = ARExperienceCoordinator(sceneDirector: sceneDirector,
                                                    audioService: audioService)
        return ARViewController(coordinator: coordinator)
    }

    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ContentView()
}
