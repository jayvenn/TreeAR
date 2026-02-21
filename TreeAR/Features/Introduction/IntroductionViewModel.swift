//
//  IntroductionViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

final class IntroductionViewModel {
    private let onBegin: () -> Void

    init(onBegin: @escaping () -> Void = {}) {
        self.onBegin = onBegin
    }

    func beginTapped() {
        onBegin()
    }
}
