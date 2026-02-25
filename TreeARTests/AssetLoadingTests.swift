//
//  AssetLoadingTests.swift
//  TreeARTests
//
//  Created by Jayven on Feb 21, 2026.
//
//  Verifies every static resource the intro screen depends on is present in
//  the app bundle and that its content is well-formed.
//
//  Runs inside the app process (BUNDLE_LOADER = TEST_HOST) so Bundle.main
//  resolves to the TreeAR app bundle and all resource lookups behave
//  identically to runtime.
//

import XCTest
import AVFoundation
@testable import TreeAR

final class AssetLoadingTests: XCTestCase {

    // MARK: - Complete inventory

    func testAllRequiredAssetsPresent() {
        let missing = AssetLoader.missingAssets()
        XCTAssertTrue(
            missing.isEmpty,
            "Missing \(missing.count) asset(s): \(missing.joined(separator: ", "))"
        )
    }

    // MARK: - Audio

    func testIntroAudioPresent() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "Intro", withExtension: "mp3"),
            "Intro.mp3 not found in app bundle"
        )
    }

    func testIntroAudioPlayable() {
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp3") else {
            return XCTFail("Intro.mp3 not found in bundle")
        }
        XCTAssertNoThrow(
            try AVAudioPlayer(contentsOf: url),
            "Intro.mp3 could not be opened by AVAudioPlayer"
        )
    }

    func testSoundEffectsPresentAndPlayable() {
        let sfxAssets: [(name: String, ext: String)] = [
            ("sfx_spirit_ambient", "mp3"),
            ("sfx_spirit_touch", "mp3"),
            ("sfx_loot_pickup", "mp3"),
            ("sfx_victory", "mp3"),
            ("sfx_player_death", "mp3"),
            ("sfx_weapon_swing", "mp3"),
        ]
        for asset in sfxAssets {
            guard let url = Bundle.main.url(forResource: asset.name, withExtension: asset.ext) else {
                XCTFail("\(asset.name).\(asset.ext) not found in app bundle")
                continue
            }
            XCTAssertNoThrow(
                try AVAudioPlayer(contentsOf: url),
                "\(asset.name).\(asset.ext) could not be opened by AVAudioPlayer"
            )
        }
    }

    // MARK: - SVG

    func testAnimatedSproutSVGPresent() {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg"),
            "AnimatedSprout.svg not found in app bundle"
        )
    }

    func testAnimatedSproutSVGContainsMarkup() {
        guard let url = Bundle.main.url(forResource: "AnimatedSprout", withExtension: "svg"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return XCTFail("AnimatedSprout.svg could not be read")
        }
        XCTAssertFalse(content.isEmpty, "AnimatedSprout.svg is empty")
        XCTAssertTrue(content.contains("<svg"), "AnimatedSprout.svg does not contain an <svg> element")
    }
}
