//
//  Constants.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit

public enum Constants {
    public static let animationDuration: TimeInterval = 1

    /// When `true`, DEMO mode (tankier player, weaker boss, spirit touch = damage + backoff).
    /// When `false`, IRL mode (original difficulty, spirit touch = instant death).
    /// Set from the intro screen DEMO/IRL toggle; default is true.
    public static var isDemoMode = true
}
