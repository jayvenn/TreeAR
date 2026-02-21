//
//  ARExperienceCoordinator.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import ARKit
import AVFoundation

// MARK: - Delegate

/// The `ARViewController` implements this protocol to react to state changes
/// without knowing anything about the business logic that produced them.
protocol ARExperienceCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: ARExperienceCoordinator,
                     didTransitionTo state: ARExperienceState)
}

// MARK: - Coordinator

/// Owns the AR adventure's state machine.
///
/// **Responsibilities:**
///   - Advance `ARExperienceState` in a strictly controlled, testable way.
///   - Orchestrate `ARSceneDirector` (what to render) and `AudioService` (what to play).
///   - Own all timers/async work and cancel them cleanly on `suspend()`.
///
/// **Threading contract:** All methods must be called from the **main thread**.
/// The coordinator never touches UIKit directly — the `delegate` (ViewController)
/// handles all UI updates in response to state transitions.
final class ARExperienceCoordinator: NSObject {

    // MARK: - Dependencies

    let sceneDirector: ARSceneDirector
    let audioService: AudioService
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - State machine

    /// Current phase of the experience.
    /// Setting this property automatically notifies the delegate.
    private(set) var state: ARExperienceState = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.coordinator(self, didTransitionTo: state)
        }
    }

    weak var delegate: ARExperienceCoordinatorDelegate?

    // MARK: - Cancellable work

    /// All in-flight `DispatchWorkItem`s. Cancelled as a group by `suspend()`.
    private var pendingWork: [DispatchWorkItem] = []

    // MARK: - Speech

    private enum SpeechString: String {
        case coding = "Coding is a superpower. Coding empowers people to do incredible things. Hope you like it."
    }

    // MARK: - Init

    init(sceneDirector: ARSceneDirector, audioService: AudioService) {
        self.sceneDirector = sceneDirector
        self.audioService  = audioService
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Lifecycle

    /// Call from `viewDidLoad`.  Warms asset caches so the first scene phase is hitch-free.
    func prepare() {
        sceneDirector.preloadAssets()
    }

    /// Call from `viewDidAppear`.  Starts audio and transitions to `.scanning`.
    func start() {
        assertMainThread()
        audioService.play(.background)
        audioService.play(.moveAround)
        transition(to: .scanning)
    }

    /// Call from `viewDidDisappear`.  Cancels all timers and stops audio cleanly.
    func suspend() {
        cancelAllPendingWork()
        audioService.stopAll()
        speechSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - AR Events (forwarded from ARSCNViewDelegate)

    /// Called once when ARKit detects the first horizontal plane.
    /// Configures the scene director and kicks off the grass-grow animation.
    func surfaceDetected(trackerNode: SCNNode) {
        assertMainThread()
        guard state == .scanning else { return }

        sceneDirector.configure(trackerNode: trackerNode)
        sceneDirector.growGrass { [weak self] in
            self?.transition(to: .awaitingGrassTap)
        }
    }

    // MARK: - User Interaction

    /// Routes a tap on a named SceneKit node through the current state's tap whitelist.
    /// Silently dropped if the node name is not valid in the current state.
    func handleTap(on nodeName: String) {
        assertMainThread()
        guard state.tappableNodeNames.contains(nodeName) else { return }

        // By the time we reach here, `tappableNodeNames` has already validated
        // that `nodeName` is legal for the current state — no redundant node-name
        // checks required below.
        switch state {
        case .awaitingGrassTap:
            beginBoxPresentation()
        case .awaitingBoxTap, .awaitingBoxTapHinted:
            beginBoxOpening()
        default:
            break
        }
    }

    // MARK: - Private — scene flow

    private func beginBoxPresentation() {
        transition(to: .boxPresenting)

        sceneDirector.dismissGrass { [weak self] in
            guard let self else { return }
            self.audioService.play(.whoa)
            self.sceneDirector.presentMagicBox { [weak self] in
                guard let self else { return }
                self.transition(to: .awaitingBoxTap)
                // Reveal the tap hint after a delay so the user can appreciate the box first
                self.schedule(after: 10) { [weak self] in
                    guard self?.state == .awaitingBoxTap else { return }
                    self?.transition(to: .awaitingBoxTapHinted)
                }
            }
        }
    }

    private func beginBoxOpening() {
        transition(to: .boxOpening)

        sceneDirector.openMagicBox { [weak self] mainNode in
            guard let self else { return }
            self.transition(to: .guardianPresenting)

            self.sceneDirector.raiseGuardian(from: mainNode) { [weak self] in
                guard let self else { return }
                self.speak(.coding)
            }

            self.schedule(after: 16) { [weak self] in
                guard let self else { return }
                self.sceneDirector.lowerGuardian { [weak self] in
                    self?.transition(to: .complete)
                }
            }
        }
    }

    // MARK: - Private — utilities

    /// Transitions to `newState`.  Must be called on the main thread.
    private func transition(to newState: ARExperienceState) {
        assertMainThread()
        state = newState
    }

    /// Schedules `block` on the main queue after `delay` seconds.
    /// The returned `DispatchWorkItem` is tracked and cancelled by `suspend()`.
    @discardableResult
    private func schedule(after delay: TimeInterval,
                           block: @escaping () -> Void) -> DispatchWorkItem {
        // Remove already-cancelled items to prevent unbounded growth
        pendingWork.removeAll { $0.isCancelled }

        let item = DispatchWorkItem(block: block)
        pendingWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return item
    }

    private func cancelAllPendingWork() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }

    private func speak(_ string: SpeechString) {
        let utterance = AVSpeechUtterance(string: string.rawValue)
        utterance.pitchMultiplier = 1.2
        utterance.rate            = 0.4
        speechSynthesizer.speak(utterance)
    }

    private func assertMainThread(function: StaticString = #function) {
        assert(Thread.isMainThread,
               "ARExperienceCoordinator.\(function) must be called on the main thread.")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ARExperienceCoordinator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        // Reserved for future chapter hooks.
    }
}
