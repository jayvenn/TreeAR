//
//  ARExperienceViewModel.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import ARKit

// MARK: - Delegate

protocol ARExperienceViewModelDelegate: AnyObject {
    func viewModel(_ vm: ARExperienceViewModel, didTransitionTo state: ARExperienceState)
    func viewModelDidUpdateCombat(_ vm: ARExperienceViewModel,
                                  playerHP: PlayerCombatState,
                                  bossHPFraction: Float,
                                  playerDistance: Float)
    func viewModelPlayerDidTakeDamage(_ vm: ARExperienceViewModel)
    func viewModelBossDidAttack(_ vm: ARExperienceViewModel)
    func viewModelBossDidEnterPhase(_ vm: ARExperienceViewModel, phase: BossPhase)
    func viewModelPlayerDidHitBoss(_ vm: ARExperienceViewModel)
    func viewModelPlayerDidSwing(_ vm: ARExperienceViewModel, isHit: Bool)
}

// MARK: - ViewModel

final class ARExperienceViewModel: NSObject {

    // MARK: - Dependencies

    let sceneDirector: ARSceneDirector
    let audioService:  AudioService

    // MARK: - Combat

    let bossCombat = BossCombatManager()
    var playerState = PlayerCombatState()
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - State

    private(set) var state: ARExperienceState = .idle {
        didSet {
            guard state != oldValue else { return }
            delegate?.viewModel(self, didTransitionTo: state)
        }
    }

    weak var delegate: ARExperienceViewModelDelegate?

    // MARK: - Cancellable work

    private var pendingWork: [DispatchWorkItem] = []

    // MARK: - Camera

    private(set) var latestCameraTransform: simd_float4x4?

    func updateCameraTransform(_ t: simd_float4x4) { latestCameraTransform = t }

    // MARK: - Init

    init(sceneDirector: ARSceneDirector, audioService: AudioService) {
        self.sceneDirector = sceneDirector
        self.audioService  = audioService
        super.init()
        bossCombat.delegate = self
        heavyHaptic.prepare()
        rigidHaptic.prepare()
        lightHaptic.prepare()
    }

    // MARK: - Lifecycle

    func prepare() { sceneDirector.preloadAssets() }

    func start() {
        assertMainThread()
        audioService.play(.background)
        audioService.play(.moveAround)
        transition(to: .scanning)
    }

    func suspend() {
        cancelAllPendingWork()
        audioService.stopAll()
    }

    // MARK: - AR Events

    func surfaceDetected(trackerNode: SCNNode) {
        assertMainThread()
        guard state == .scanning else { return }
        sceneDirector.configure(trackerNode: trackerNode)
        sceneDirector.growGrass { [weak self] in
            self?.transition(to: .awaitingGrassTap)
        }
    }

    // MARK: - Tap Handling

    func handleTap(on nodeName: String) {
        assertMainThread()
        guard state.tappableNodeNames.contains(nodeName) else { return }
        if state == .awaitingGrassTap {
            beginBossSequence()
        }
    }

    /// Tap-to-attack: triggers a weapon swing, with the hit check at the swing apex.
    func handleCombatTap() {
        assertMainThread()
        guard state.acceptsCombatTaps else { return }

        let now = CACurrentMediaTime()
        guard playerState.canAttack(at: now) else { return }
        playerState.recordAttack(at: now)

        let didSwing = sceneDirector.swingWeapon(
            onApex: { [weak self] in
                self?.performHitCheck()
            },
            onComplete: { }
        )

        if didSwing {
            audioService.play(.whiff)
            delegate?.viewModelPlayerDidSwing(self, isHit: false)
        }
    }

    func handleRetry() {
        assertMainThread()
        guard state == .playerDefeated else { return }
        playerState.reset()
        bossCombat.reset()
        sceneDirector.removeBoss()
        sceneDirector.removeWeapon()
        beginBossSpawn()
    }

    // MARK: - Per-Frame Combat

    func updateCombat(atTime time: TimeInterval, cameraTransform: simd_float4x4) {
        guard state == .combatActive else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 { dt = 1.0 / 60.0 }
        else { dt = min(time - lastUpdateTime, 0.1) }
        lastUpdateTime = time

        playerState.update(deltaTime: dt)

        let dist = sceneDirector.distanceToBoss(cameraTransform: cameraTransform)
        bossCombat.update(deltaTime: dt, playerDistance: dist)
        sceneDirector.updateBossFacing(cameraTransform: cameraTransform)

        if bossCombat.isExecutingAttack, let attack = bossCombat.currentAttack {
            let inRange = dist <= attack.threatRadius
            let arcOK = !attack.isFrontalOnly ||
                !sceneDirector.isCameraBehindBoss(cameraTransform: cameraTransform)

            if inRange && arcOK && !playerState.isInvulnerable {
                playerState.takeDamage(attack.damage)
                delegate?.viewModelPlayerDidTakeDamage(self)
                rigidHaptic.impactOccurred(intensity: 1.0)

                if !playerState.isAlive {
                    transition(to: .playerDefeated)
                }
            }
        }

        delegate?.viewModelDidUpdateCombat(self,
                                           playerHP: playerState,
                                           bossHPFraction: bossCombat.hpFraction,
                                           playerDistance: dist)
    }

    // MARK: - Private — Hit Check (fires at swing apex)

    private func performHitCheck() {
        assertMainThread()
        guard state == .combatActive else { return }
        guard let cam = latestCameraTransform else { return }
        let dist = sceneDirector.distanceToBoss(cameraTransform: cam)

        if dist <= playerState.attackRange {
            bossCombat.takeDamage(playerState.attackDamage)
            sceneDirector.playBossHitEffect()
            sceneDirector.playWeaponHitFlare()
            heavyHaptic.impactOccurred(intensity: 1.0)
            delegate?.viewModelPlayerDidHitBoss(self)
            audioService.play(.hit)
        }
    }

    // MARK: - Private — Flow

    private func beginBossSequence() {
        sceneDirector.dismissGrass { [weak self] in
            self?.beginBossSpawn()
        }
    }

    private func beginBossSpawn() {
        transition(to: .bossSpawning)
        audioService.play(.bossIntro)
        audioService.stop(.background)

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

    // MARK: - Private — Utilities

    private func transition(to s: ARExperienceState) {
        assertMainThread()
        state = s
    }

    @discardableResult
    private func schedule(after delay: TimeInterval, block: @escaping () -> Void) -> DispatchWorkItem {
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

    private func assertMainThread(function: StaticString = #function) {
        assert(Thread.isMainThread,
               "ARExperienceViewModel.\(function) must be called on the main thread.")
    }
}

// MARK: - BossCombatDelegate

extension ARExperienceViewModel: BossCombatDelegate {

    func combatManager(_ m: BossCombatManager, bossDidSelectAttack attack: BossAttack) {
        sceneDirector.playTelegraphAnimation(for: attack)
        audioService.play(.telegraph)
    }

    func combatManager(_ m: BossCombatManager, bossDidExecuteAttack attack: BossAttack) {
        sceneDirector.playExecuteAnimation(for: attack)
        delegate?.viewModelBossDidAttack(self)
        audioService.play(.bossAttack)
    }

    func combatManager(_ m: BossCombatManager, bossDidFinishRecoveryFrom attack: BossAttack) {
        sceneDirector.playRecoveryAnimation(for: attack)
    }

    func combatManager(_ m: BossCombatManager, bossDidEnterPhase phase: BossPhase) {
        sceneDirector.playEnrageEffect(phase: phase)
        delegate?.viewModelBossDidEnterPhase(self, phase: phase)
        audioService.play(.bossRoar)
    }

    func combatManagerBossDidDie(_ m: BossCombatManager) {
        transition(to: .bossDefeated)
        audioService.stop(.combatLoop)
        audioService.play(.bossDefeat)

        sceneDirector.playBossDeathAnimation { [weak self] in
            guard let self else { return }
            self.sceneDirector.removeBoss()
            self.sceneDirector.removeWeapon()
            self.transition(to: .victory)
        }
    }

    func combatManager(_ m: BossCombatManager, bossDidTaunt: Void) {
        audioService.play(.bossRoar)
    }
}
