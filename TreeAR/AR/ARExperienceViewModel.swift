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
    func viewModelPlayerDidPickupLoot(_ vm: ARExperienceViewModel, type: LootType)
    func viewModelMachineGunDidExpire(_ vm: ARExperienceViewModel)
    func viewModelDidUpdateChase(_ vm: ARExperienceViewModel, secondsLeft: Int)
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

    // MARK: - Loot

    private var lootSpawnTimer: TimeInterval = 0
    private let lootSpawnInterval: ClosedRange<TimeInterval> = 12...20
    private var wasMachineGunActive = false

    // MARK: - Spirit Chase

    private static let chaseDuration: TimeInterval = 20
    private static let spiritCatchDistance: Float = 0.8
    private static let spiritBackoffDuration: TimeInterval = 2.2
    private static let spiritRetreatSpeed: Float = 2.8
    private static let spiritBaseSpeed: Float = 1.5
    private static let spiritMaxSpeed: Float = 3.5
    /// Damage per spirit touch (nightmare only; demo applies zero).
    private static let spiritTouchDamage: Int = 25
    private var chaseTimer: TimeInterval = 0
    private var spiritBackoffTimer: TimeInterval = 0

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
        audioService.activateSession()
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

    func handleCombatTap(at location: CGPoint, in sceneView: ARSCNView) {
        assertMainThread()
        guard state.acceptsCombatTaps else { return }

        if let lootName = sceneDirector.rootLootName(at: location, in: sceneView),
           let type = sceneDirector.lootType(forNodeName: lootName),
           let cam = latestCameraTransform,
           let dist = sceneDirector.distanceToLoot(named: lootName, cameraTransform: cam),
           dist <= type.pickupRange {
            pickupLoot(type: type, named: lootName)
            return
        }

        let now = CACurrentMediaTime()
        guard playerState.canAttack(at: now) else { return }
        playerState.recordAttack(at: now)

        if playerState.isMachineGunActive {
            performRapidJab()
        } else {
            performSwordSwing()
        }
    }

    func handleRetry() {
        assertMainThread()
        guard state == .playerDefeated else { return }

        playerState.reset()
        bossCombat.reset()
        lootSpawnTimer = 0
        chaseTimer = 0
        wasMachineGunActive = false

        sceneDirector.removeSpirit()
        sceneDirector.removeAllLoot()
        sceneDirector.removeBoss()
        sceneDirector.deactivateMachineGunMode()
        sceneDirector.resetWeaponState()

        cancelAllPendingWork()

        beginBossSpawn()
    }

    // MARK: - Per-Frame Combat

    func updateCombat(atTime time: TimeInterval, cameraTransform: simd_float4x4) {
        guard state == .combatActive else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 { dt = 1.0 / 60.0 }
        else { dt = min(time - lastUpdateTime, 0.1) }
        lastUpdateTime = time

        let wasMG = playerState.isMachineGunActive
        playerState.update(deltaTime: dt)

        if wasMG && !playerState.isMachineGunActive {
            sceneDirector.deactivateMachineGunMode()
            delegate?.viewModelMachineGunDidExpire(self)
        }

        let dist = sceneDirector.distanceToBoss(cameraTransform: cameraTransform)
        bossCombat.update(deltaTime: dt, playerDistance: dist)
        sceneDirector.updateBossFacing(cameraTransform: cameraTransform)

        if bossCombat.wantsToAdvance {
            sceneDirector.advanceBossToward(
                cameraTransform: cameraTransform,
                speed: bossCombat.phase.moveSpeed,
                deltaTime: Float(dt)
            )
        }

        if bossCombat.isExecutingAttack, let attack = bossCombat.currentAttack {
            let inRange = dist <= attack.threatRadius
            let arcOK = !attack.isFrontalOnly ||
                !sceneDirector.isCameraBehindBoss(cameraTransform: cameraTransform)

            if inRange && arcOK && !playerState.isInvulnerable {
                if Constants.isDemoMode {
                    delegate?.viewModelPlayerDidTakeDamage(self)
                    rigidHaptic.impactOccurred(intensity: 1.0)
                } else {
                    playerState.takeDamage(attack.damage)
                    delegate?.viewModelPlayerDidTakeDamage(self)
                    rigidHaptic.impactOccurred(intensity: 1.0)
                    if !playerState.isAlive {
                        audioService.play(.playerDeath)
                        transition(to: .playerDefeated)
                    }
                }
            }
        }

        updateLootSpawn(dt: dt)

        delegate?.viewModelDidUpdateCombat(self,
                                           playerHP: playerState,
                                           bossHPFraction: bossCombat.hpFraction,
                                           playerDistance: dist)
    }

    // MARK: - Private — Loot

    private func updateLootSpawn(dt: TimeInterval) {
        lootSpawnTimer -= dt
        if lootSpawnTimer <= 0 {
            let type: LootType = Bool.random() ? .healthPack : .wizardMachineGun
            sceneDirector.spawnLoot(type: type)
            lootSpawnTimer = .random(in: lootSpawnInterval)
        }
    }

    private func pickupLoot(type: LootType, named name: String) {
        sceneDirector.pickupLoot(named: name)
        audioService.play(.lootPickup)
        lightHaptic.impactOccurred(intensity: 1.0)
        delegate?.viewModelPlayerDidPickupLoot(self, type: type)

        switch type {
        case .healthPack:
            playerState.heal(playerState.healAmount)
        case .wizardMachineGun:
            playerState.activateMachineGun()
            sceneDirector.activateMachineGunMode()
        }
    }

    // MARK: - Private — Attacks

    private func performSwordSwing() {
        let didSwing = sceneDirector.swingWeapon(
            onApex: { [weak self] in self?.performHitCheck() },
            onComplete: { }
        )
        if didSwing {
            audioService.play(.weaponSwing)
        }
    }

    private func performRapidJab() {
        let didJab = sceneDirector.rapidJabWeapon(
            onApex: { [weak self] in self?.performHitCheck() },
            onComplete: { }
        )
        if didJab {
            audioService.play(.weaponSwing)
        }
    }

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
        } else {
            audioService.play(.whiff)
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

        sceneDirector.spawnBoss { [weak self] in
            guard let self else { return }
            self.lastUpdateTime = 0
            self.playerState.reset()
            self.bossCombat.reset()
            self.lootSpawnTimer = .random(in: 8...14)
            self.wasMachineGunActive = false
            self.bossCombat.beginFight()
            self.transition(to: .combatActive)
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
        audioService.play(.bossDefeat)

        sceneDirector.removeAllLoot()

        let bossWorldPos = sceneDirector.bossNode?.worldPosition ?? SCNVector3Zero
        sceneDirector.playBossDeathAnimation { [weak self] in
            guard let self else { return }
            self.sceneDirector.removeBoss()
            self.beginSpiritChase(from: bossWorldPos)
        }
    }

    private func beginSpiritChase(from position: SCNVector3) {
        chaseTimer = Self.chaseDuration
        spiritBackoffTimer = 0
        lastUpdateTime = 0
        sceneDirector.spawnSpirit(at: position)
        audioService.play(.spiritAmbient)
        transition(to: .spiritChase)
    }

    func updateSpiritChase(atTime time: TimeInterval, cameraTransform: simd_float4x4) {
        guard state == .spiritChase else { return }

        let dt: TimeInterval
        if lastUpdateTime == 0 { dt = 1.0 / 60.0 }
        else { dt = min(time - lastUpdateTime, 0.1) }
        lastUpdateTime = time

        chaseTimer -= dt
        playerState.update(deltaTime: dt)

        let secondsLeft = max(0, Int(ceil(chaseTimer)))
        delegate?.viewModelDidUpdateChase(self, secondsLeft: secondsLeft)
        delegate?.viewModelDidUpdateCombat(self, playerHP: playerState, bossHPFraction: 0, playerDistance: 0)

        if Constants.isDemoMode, spiritBackoffTimer > 0 {
            spiritBackoffTimer -= dt
            _ = sceneDirector.retreatSpirit(
                from: cameraTransform,
                speed: Self.spiritRetreatSpeed,
                deltaTime: Float(dt)
            )
        } else {
            let progress = Float(1.0 - chaseTimer / Self.chaseDuration)
            let speed = Self.spiritBaseSpeed + (Self.spiritMaxSpeed - Self.spiritBaseSpeed) * progress

            let dist = sceneDirector.advanceSpiritToward(
                cameraTransform: cameraTransform,
                speed: speed,
                deltaTime: Float(dt)
            )

            if dist < Self.spiritCatchDistance {
                if Constants.isDemoMode {
                    audioService.play(.spiritTouch)
                    rigidHaptic.impactOccurred(intensity: 0.8)
                    delegate?.viewModelPlayerDidTakeDamage(self)
                    sceneDirector.playSpiritBackoffEffect()
                    spiritBackoffTimer = Self.spiritBackoffDuration
                } else {
                    playerState.takeDamage(Self.spiritTouchDamage)
                    audioService.play(.spiritTouch)
                    rigidHaptic.impactOccurred(intensity: 0.8)
                    delegate?.viewModelPlayerDidTakeDamage(self)
                    sceneDirector.playSpiritBackoffEffect()
                    spiritBackoffTimer = Self.spiritBackoffDuration
                    if !playerState.isAlive {
                        audioService.stop(.spiritAmbient)
                        audioService.play(.playerDeath)
                        sceneDirector.removeSpirit()
                        transition(to: .playerDefeated)
                        return
                    }
                }
            }
        }

        if chaseTimer <= 0 {
            audioService.stop(.spiritAmbient)
            audioService.play(.victory)
            sceneDirector.removeSpirit()
            transition(to: .victory)
        }
    }

    func combatManager(_ m: BossCombatManager, bossDidTaunt: Void) {
        audioService.play(.bossRoar)
    }
}
