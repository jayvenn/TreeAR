//
//  ContentView.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        IntroductionViewRepresentable(viewModel: IntroductionViewModel())
            .ignoresSafeArea()
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

#Preview {
    ContentView()
}
