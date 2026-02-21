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
        case somethingMoving
        case whoa
        case background

        fileprivate var resource: String {
            switch self {
            case .moveAround:      return "Move around"
            case .somethingMoving: return "Something is moving"
            case .whoa:            return "Whoa"
            case .background:      return "SunnyWeather"
            }
        }

        fileprivate var fileExtension: String { "m4a" }
        fileprivate var loops: Bool          { self == .background }
        fileprivate var volume: Float        { self == .background ? 0.2 : 1.0 }
    }

    // MARK: - Properties

    private var players: [Track: AVAudioPlayer] = [:]

    // MARK: - Init

    init() {
        preloadAllTracks()
    }

    // MARK: - Public API

    func play(_ track: Track) {
        players[track]?.play()
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
