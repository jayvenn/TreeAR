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

    // MARK: - Sound effects (spirit chase & feedback)

    static let sfxSpiritAmbient = Asset(name: "sfx_spirit_ambient", fileExtension: "mp3")
    static let sfxSpiritTouch   = Asset(name: "sfx_spirit_touch",   fileExtension: "mp3")
    static let sfxLootPickup    = Asset(name: "sfx_loot_pickup",   fileExtension: "mp3")
    static let sfxVictory       = Asset(name: "sfx_victory",       fileExtension: "mp3")
    static let sfxPlayerDeath   = Asset(name: "sfx_player_death",  fileExtension: "mp3")
    static let sfxWeaponSwing   = Asset(name: "sfx_weapon_swing",  fileExtension: "mp3")

    // MARK: - All assets

    static let allAssets: [Asset] = [
        audioIntro,
        animatedSprout,
        sfxSpiritAmbient,
        sfxSpiritTouch,
        sfxLootPickup,
        sfxVictory,
        sfxPlayerDeath,
        sfxWeaponSwing,
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
