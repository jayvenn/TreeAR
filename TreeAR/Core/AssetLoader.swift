//
//  AssetLoader.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//
//  Single source of truth for every static resource the app loads from the bundle.
//  Use `AssetLoader.missingAssets()` to validate the bundle at runtime or in tests.
//

import Foundation

enum AssetLoader {

    // MARK: - Asset descriptor

    struct Asset: Equatable {
        let name: String
        let fileExtension: String

        var filename: String { "\(name).\(fileExtension)" }

        /// Returns the URL for this asset in the given bundle (default: `.main`).
        func url(in bundle: Bundle = .main) -> URL? {
            bundle.url(forResource: name, withExtension: fileExtension)
        }
    }

    // MARK: - Introduction screen

    static let audioIntro     = Asset(name: "Intro",          fileExtension: "mp3")
    static let animatedSprout = Asset(name: "AnimatedSprout", fileExtension: "svg")

    // MARK: - All assets

    static let allAssets: [Asset] = [
        audioIntro,
        animatedSprout,
    ]

    // MARK: - Validation

    /// Returns the filenames of any assets not found in `bundle`.
    /// An empty array means all assets are present.
    static func missingAssets(in bundle: Bundle = .main) -> [String] {
        allAssets.compactMap { asset in
            asset.url(in: bundle) == nil ? asset.filename : nil
        }
    }
}
