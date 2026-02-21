//
//  ContentView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SwiftUI

struct ContentView: View {
    @State private var coordinator = AppCoordinator()
    
    var body: some View {
        IntroductionViewRepresentable(viewModel: IntroductionViewModel(coordinator: coordinator))
            .ignoresSafeArea()
            .fullScreenCover(isPresented: coordinator.arPresentationBinding()) {
                ARViewRepresentable(
                    viewModel: ARViewModel(coordinator: coordinator)
                )
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
    let viewModel: ARViewModel
    
    func makeUIViewController(context: Context) -> ARViewController {
        let vc = ARViewController()
        vc.viewModel = viewModel
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ContentView()
}
