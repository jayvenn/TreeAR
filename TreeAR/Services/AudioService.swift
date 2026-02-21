//
//  AudioService.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import AVFoundation

/// Centralised audio manager.
///
/// All players are pre-loaded at init time on a background thread so that
/// the first `play(_:)` call incurs zero disk I/O on the main thread.
/// Missing audio files are silently skipped — the experience degrades gracefully.
final class AudioService {

    // MARK: - Tracks

    enum Track: CaseIterable {
        case moveAround
        case background

        // Combat audio
        case hit
        case whiff
        case telegraph
        case bossAttack
        case bossRoar
        case bossIntro
        case bossDefeat

        fileprivate var resource: String {
            switch self {
            case .moveAround:      return "Move around"
            case .background:      return "Echoes of the Emerald"
            case .hit:             return "combat_hit"
            case .whiff:           return "combat_whiff"
            case .telegraph:       return "combat_telegraph"
            case .bossAttack:      return "combat_boss_attack"
            case .bossRoar:        return "combat_boss_roar"
            case .bossIntro:       return "combat_boss_intro"
            case .bossDefeat:      return "combat_boss_defeat"
            }
        }

        fileprivate var fileExtension: String { "mp3" }

        fileprivate var loops: Bool {
            self == .background
        }

        fileprivate var volume: Float {
            switch self {
            case .background:   return 0.2
            case .telegraph:    return 0.5
            case .whiff:        return 0.4
            default:            return 1.0
            }
        }
    }

    // MARK: - Properties

    private var players: [Track: AVAudioPlayer] = [:]

    // MARK: - Init

    init() {
        preloadAllTracks()
    }

    // MARK: - Public API

    func play(_ track: Track) {
        guard let player = players[track] else { return }
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }

    func stop(_ track: Track) {
        players[track]?.stop()
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }

    // MARK: - Private

    private func preloadAllTracks() {
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
        }
    }
}
