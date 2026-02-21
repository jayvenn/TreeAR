//
//  ARExperienceViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import ARKit
import AVFoundation

// MARK: - Delegate

/// `ARViewController` conforms to this protocol to receive state-change
/// notifications without knowing anything about the business logic that produced them.
protocol ARExperienceViewModelDelegate: AnyObject {
    func viewModel(_ viewModel: ARExperienceViewModel,
                   didTransitionTo state: ARExperienceState)
    func viewModelDidUpdateCombat(_ viewModel: ARExperienceViewModel,
                                  playerHP: PlayerCombatState,
                                  bossHPFraction: Float,
                                  playerDistance: Float)
    func viewModelPlayerDidTakeDamage(_ viewModel: ARExperienceViewModel)
    func viewModelBossDidEnterPhase(_ viewModel: ARExperienceViewModel, phase: BossPhase)
}

// MARK: - ViewModel

/// Manages all presentation state for the AR experience screen.
///
/// **Responsibilities:**
///   - Advance `ARExperienceState` in a strictly controlled, testable way.
///   - Orchestrate `ARSceneDirector` (what to render) and `AudioService` (what to play).
///   - Own all timers/async work so they can be cancelled cleanly via `suspend()`.
///   - Drive combat loop via per-frame updates during `.combatActive`.
///
/// **Threading contract:** All public methods must be called from the **main thread**.
/// The ViewModel never touches UIKit — the `delegate` (ViewController) owns all UI.
final class ARExperienceViewModel: NSObject {

    // MARK: - Dependencies

    let sceneDirector: ARSceneDirector
    let audioService:  AudioService
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Combat subsystem

    let bossCombat = BossCombatManager()
    var playerState = PlayerCombatState()
    private let haptics = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptics = UIImpactFeedbackGenerator(style: .light)
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - State machine

    /// Current phase of the AR experience.
    /// Every assignment automatically notifies the delegate.
    private(set) var state: ARExperienceState = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.viewModel(self, didTransitionTo: state)
        }
    }

    weak var delegate: ARExperienceViewModelDelegate?

    // MARK: - Cancellable work

    /// All in-flight `DispatchWorkItem`s — cancelled as a group by `suspend()`.
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
        bossCombat.delegate = self
        haptics.prepare()
        lightHaptics.prepare()
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

    /// Routes a tap on a named SceneKit node through the current state's whitelist.
    /// Silently dropped if the node name is not valid in the current state.
    func handleTap(on nodeName: String) {
        assertMainThread()
        guard state.tappableNodeNames.contains(nodeName) else { return }

        switch state {
        case .awaitingGrassTap:
            beginBoxPresentation()
        case .awaitingBoxTap, .awaitingBoxTapHinted:
            beginBoxOpening()
        default:
            break
        }
    }

    /// Tap-to-attack during combat. Called for any screen tap.
    func handleCombatTap() {
        assertMainThread()
        guard state.acceptsCombatTaps else { return }

        let now = CACurrentMediaTime()
        guard playerState.canAttack(at: now) else { return }
        playerState.recordAttack(at: now)

        guard let cameraTransform = currentCameraTransform() else { return }
        let distance = sceneDirector.distanceToBoss(cameraTransform: cameraTransform)

        if distance <= playerState.attackRange {
            bossCombat.takeDamage(playerState.attackDamage)
            sceneDirector.playBossHitFlash()
            haptics.impactOccurred()
            audioService.play(.hit)
        } else {
            lightHaptics.impactOccurred()
            audioService.play(.whiff)
        }
    }

    /// Retry after player death.
    func handleRetry() {
        assertMainThread()
        guard state == .playerDefeated else { return }
        playerState.reset()
        bossCombat.reset()
        sceneDirector.removeBoss()
        beginBossSpawn()
    }

    // MARK: - Per-Frame Update (called from renderer delegate)

    /// The ViewController's `SCNSceneRendererDelegate` calls this every frame during combat.
    func updateCombat(atTime time: TimeInterval, cameraTransform: simd_float4x4) {
        guard state == .combatActive else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(time - lastUpdateTime, 0.1)
        }
        lastUpdateTime = time

        playerState.update(deltaTime: dt)

        let distance = sceneDirector.distanceToBoss(cameraTransform: cameraTransform)
        bossCombat.update(deltaTime: dt, playerDistance: distance)

        sceneDirector.updateBossFacing(cameraTransform: cameraTransform)

        if bossCombat.isExecutingAttack, let attack = bossCombat.currentAttack {
            let inThreatRange = distance <= attack.threatRadius
            let passesArcCheck = !attack.isFrontalOnly ||
                !sceneDirector.isCameraBehindBoss(cameraTransform: cameraTransform)

            if inThreatRange && passesArcCheck && !playerState.isInvulnerable {
                playerState.takeDamage(attack.damage)
                delegate?.viewModelPlayerDidTakeDamage(self)
                haptics.impactOccurred()

                if !playerState.isAlive {
                    transition(to: .playerDefeated)
                }
            }
        }

        delegate?.viewModelDidUpdateCombat(self,
                                           playerHP: playerState,
                                           bossHPFraction: bossCombat.hpFraction,
                                           playerDistance: distance)
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
                self?.speak(.coding)
            }

            self.schedule(after: 16) { [weak self] in
                guard let self else { return }
                self.sceneDirector.lowerGuardian { [weak self] in
                    self?.beginBossSpawn()
                }
            }
        }
    }

    private func beginBossSpawn() {
        transition(to: .bossSpawning)
        audioService.play(.bossIntro)

        sceneDirector.spawnBoss { [weak self] in
            guard let self else { return }
            self.lastUpdateTime = 0
            self.playerState.reset()
            self.bossCombat.reset()
            self.bossCombat.beginFight()
            self.transition(to: .combatActive)
            self.audioService.play(.combatLoop)
        }
    }

    // MARK: - Private — camera access

    /// Stored by the ViewController so the ViewModel can read it without holding ARSCNView.
    private(set) var latestCameraTransform: simd_float4x4?

    func updateCameraTransform(_ transform: simd_float4x4) {
        latestCameraTransform = transform
    }

    private func currentCameraTransform() -> simd_float4x4? {
        latestCameraTransform
    }

    // MARK: - Private — utilities

    private func transition(to newState: ARExperienceState) {
        assertMainThread()
        state = newState
    }

    @discardableResult
    private func schedule(after delay: TimeInterval,
                          block: @escaping () -> Void) -> DispatchWorkItem {
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
               "ARExperienceViewModel.\(function) must be called on the main thread.")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension ARExperienceViewModel: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        // Reserved for future chapter hooks.
    }
}

// MARK: - BossCombatDelegate

extension ARExperienceViewModel: BossCombatDelegate {

    func combatManager(_ manager: BossCombatManager, bossDidSelectAttack attack: BossAttack) {
        sceneDirector.playTelegraphAnimation(for: attack)
        audioService.play(.telegraph)
    }

    func combatManager(_ manager: BossCombatManager, bossDidExecuteAttack attack: BossAttack) {
        sceneDirector.playExecuteAnimation(for: attack)
        audioService.play(.bossAttack)
    }

    func combatManager(_ manager: BossCombatManager, bossDidFinishRecoveryFrom attack: BossAttack) {
        sceneDirector.playRecoveryAnimation(for: attack)
    }

    func combatManager(_ manager: BossCombatManager, bossDidEnterPhase phase: BossPhase) {
        sceneDirector.playEnrageEffect(phase: phase)
        delegate?.viewModelBossDidEnterPhase(self, phase: phase)
        audioService.play(.bossRoar)
    }

    func combatManagerBossDidDie(_ manager: BossCombatManager) {
        transition(to: .bossDefeated)
        audioService.stop(.combatLoop)
        audioService.play(.bossDefeat)

        sceneDirector.playBossDeathAnimation { [weak self] in
            guard let self else { return }
            self.sceneDirector.removeBoss()
            self.transition(to: .victory)
        }
    }

    func combatManager(_ manager: BossCombatManager, bossDidTaunt: Void) {
        audioService.play(.bossRoar)
    }
}
