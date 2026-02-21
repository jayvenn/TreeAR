//
//  ContentView.swift
//  TreeAR
//
//  Root view wired to AppCoordinator. Renders the current route.
//

import SwiftUI

struct ContentView: View {
    @State private var coordinator = AppCoordinator()
    
    var body: some View {
        IntroductionViewRepresentable(viewModel: IntroductionViewModel(coordinator: coordinator))
            .fullScreenCover(isPresented: coordinator.arPresentationBinding()) {
                ARViewRepresentable(
                    viewModel: ARViewModel(coordinator: coordinator)
                )
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
