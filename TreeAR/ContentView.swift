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
        ARViewController()
    }
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {}
}

#Preview {
    ContentView()
}
