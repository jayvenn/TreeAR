//
//  AppCoordinator.swift
//  TreeAR
//
//  Coordinates app navigation flow. The "C" in MVVM-C.
//  Owns navigation state and presents/dismisses screens.
//

import SwiftUI

@Observable
final class AppCoordinator {
    
    enum Route {
        case introduction
        case ar
    }
    
    private(set) var currentRoute: Route = .introduction
    
    var isShowingAR: Bool { currentRoute == .ar }
    
    func showAR() {
        currentRoute = .ar
    }
    
    func dismissAR() {
        currentRoute = .introduction
    }
    
    /// Binding for SwiftUI fullScreenCover(isPresented:)
    func arPresentationBinding() -> Binding<Bool> {
        Binding(
            get: { self.currentRoute == .ar },
            set: { if !$0 { self.dismissAR() } }
        )
    }
}
