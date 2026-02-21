//
//  TreeARApp.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SwiftUI

@main
struct TreeARApp: App {

    /// The single app-level coordinator that manages screen-to-screen navigation.
    /// `@State` is correct for `@Observable` types (replaces `@StateObject`).
    @State private var appCoordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: appCoordinator)
        }
    }
}
