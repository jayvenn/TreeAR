//
//  AudioService.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import AVFoundation

/// Centralised audio manager.
///
/// - Preloads all tracks and voiceover clips on a background thread at init; playback
///   incurs no disk I/O on the main thread.
/// - Playback is dispatched to the main thread (AVAudioPlayer is not thread-safe).
/// - Call `activateSession()` when starting playback (e.g. when AR experience starts)
///   so multiple sounds mix correctly. `stopAll()` deactivates the session so other apps
///   can use audio when the experience ends.
/// - Missing audio files are silently skipped.
final class AudioService {

    // MARK: - Tracks

    enum Track: CaseIterable {
        case moveAround
        case background

        // Combat audio
        case weaponSwing
        case hit
        case whiff
        case bossAttack
        case bossRoar
        case bossIntro
        case bossDefeat

        // Spirit chase & feedback
        case spiritAmbient
        case spiritTouch
        case lootPickup
        case victory
        case playerDeath

        fileprivate var resource: String {
            switch self {
            case .moveAround:      return "Move around"
            case .background:      return "Echoes of the Emerald"
            case .weaponSwing:     return "sfx_weapon_swing"
            case .hit:             return "combat_hit"
            case .whiff:           return "combat_whiff"
            case .bossAttack:      return "combat_boss_attack"
            case .bossRoar:        return "combat_boss_roar"
            case .bossIntro:       return "combat_boss_intro"
            case .bossDefeat:      return "combat_boss_defeat"
            case .spiritAmbient:   return "sfx_spirit_ambient"
            case .spiritTouch:     return "sfx_spirit_touch"
            case .lootPickup:     return "sfx_loot_pickup"
            case .victory:        return "sfx_victory"
            case .playerDeath:    return "sfx_player_death"
            }
        }

        fileprivate var fileExtension: String { "mp3" }

        fileprivate var loops: Bool {
            self == .background || self == .spiritAmbient
        }

        fileprivate var volume: Float {
            switch self {
            case .background:     return 0.2
            case .weaponSwing:   return 0.7
            case .whiff:         return 0.4
            case .spiritAmbient: return 0.35
            case .spiritTouch:   return 0.9
            case .lootPickup:    return 0.8
            case .victory:       return 0.9
            case .playerDeath:   return 0.85
            default:             return 1.0
            }
        }
    }

    // MARK: - Voiceover

    enum Voiceover: CaseIterable {
        case tapAttack
        case dodge
        case telegraph
        case phase2
        case phase3
        case spiritChase
        case bossSpawn
        case victory
        case defeat
        case bossDefeat

        fileprivate var resource: String {
            switch self {
            case .tapAttack:    return "vo_tap_attack"
            case .dodge:        return "vo_dodge"
            case .telegraph:    return "vo_telegraph"
            case .phase2:       return "vo_phase2"
            case .phase3:       return "vo_phase3"
            case .spiritChase:  return "vo_spirit_chase"
            case .bossSpawn:    return "vo_boss_spawn"
            case .victory:      return "vo_victory"
            case .defeat:       return "vo_defeat"
            case .bossDefeat:   return "vo_boss_defeat"
            }
        }
    }

    // MARK: - Properties

    private var players: [Track: AVAudioPlayer] = [:]
    private var voPlayers: [Voiceover: AVAudioPlayer] = [:]
    private var activeVO: Voiceover?

    // MARK: - Init

    init() {
        preloadAll()
    }

    /// Configures and activates the audio session so multiple sounds (music, SFX, VO) mix
    /// without cutting each other off. Call when starting playback (e.g. when AR experience starts).
    func activateSession() {
        runOnMainIfNeeded {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                // Session may already be in use (e.g. by AR); non-fatal.
            }
        }
    }

    // MARK: - Public API

    func play(_ track: Track) {
        runOnMainIfNeeded {
            guard let player = self.players[track] else { return }
            if player.isPlaying { player.currentTime = 0 }
            player.play()
        }
    }

    func stop(_ track: Track) {
        runOnMainIfNeeded {
            self.players[track]?.stop()
        }
    }

    /// Plays a preloaded voiceover clip, stopping any currently playing VO.
    /// Missing files are silently ignored.
    func playVO(_ vo: Voiceover) {
        runOnMainIfNeeded {
            if let active = self.activeVO { self.voPlayers[active]?.stop() }
            guard let player = self.voPlayers[vo] else { return }
            player.currentTime = 0
            player.play()
            self.activeVO = vo
        }
    }

    func stopVO() {
        runOnMainIfNeeded {
            if let active = self.activeVO {
                self.voPlayers[active]?.stop()
                self.activeVO = nil
            }
        }
    }

    /// Duration in seconds of the given voiceover clip (0 if not loaded).
    /// Call from main thread. Use with tip display so the tip stays up until VO finishes + delay.
    func voDuration(for vo: Voiceover) -> TimeInterval {
        voPlayers[vo]?.duration ?? 0
    }

    func stopAll() {
        runOnMainIfNeeded {
            self.players.values.forEach { $0.stop() }
            if let active = self.activeVO {
                self.voPlayers[active]?.stop()
                self.activeVO = nil
            }
            let session = AVAudioSession.sharedInstance()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Ensures the block runs on the main thread (AVAudioPlayer is not thread-safe).
    private func runOnMainIfNeeded(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    // MARK: - Private

    private func preloadAll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for track in Track.allCases {
                guard let url = Bundle.main.url(forResource: track.resource,
                                                withExtension: track.fileExtension),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.numberOfLoops = track.loops ? -1 : 0
                player.volume = track.volume
                player.prepareToPlay()
                DispatchQueue.main.async { self.players[track] = player }
            }
            for vo in Voiceover.allCases {
                guard let url = Bundle.main.url(forResource: vo.resource,
                                                withExtension: "mp3"),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.volume = 0.85
                player.prepareToPlay()
                DispatchQueue.main.async { self.voPlayers[vo] = player }
            }
        }
    }
}
