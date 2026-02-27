//
//  ARViewController.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit
import ARKit

/// Thin presentation layer for the AR experience.
final class ARViewController: UIViewController {

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?

    // MARK: - Dependencies

    private let viewModel: ARExperienceViewModel

    // MARK: - AR

    private let sceneView = ARSCNView(frame: .zero)
    private var weaponAttached = false
    private var playedVOKeys = Set<AudioService.Voiceover>()
    private var pendingDelayWork: [DispatchWorkItem] = []
    private var arSessionPausedByAppBackground = false

    // MARK: - UI

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment          = .center
        label.font                   = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor              = UIColor.white.withAlphaComponent(0.8)
        label.numberOfLines          = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor     = 0.5
        label.backgroundColor        = UIColor.black.withAlphaComponent(0.35)
        label.layer.cornerRadius     = 10
        label.layer.masksToBounds    = true
        label.alpha                  = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var surfaceScanningView: SurfaceScanningView = {
        let v = SurfaceScanningView()
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var combatHUD: CombatHUDView = {
        let hud = CombatHUDView(frame: .zero)
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alpha = 0
        hud.isUserInteractionEnabled = true
        hud.onRetryTapped = { [weak self] in self?.onDismiss?() }
        hud.onVictoryDismiss = { [weak self] in self?.onDismiss?() }
        return hud
    }()

    // MARK: - Init

    init(viewModel: ARExperienceViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(viewModel:)") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupLayout()
        setupTapGesture()
        viewModel.delegate = self
        viewModel.prepare()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startARSession()
        viewModel.start()
        observeAppLifecycle()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopObservingAppLifecycle()
        sceneView.delegate = nil
        sceneView.session.pause()
        pendingDelayWork.forEach { $0.cancel() }
        pendingDelayWork.removeAll()
        viewModel.suspend()
    }

    // MARK: - AR Session

    private func startARSession() {
        sceneView.session.run(makeARConfig(planeDetection: .horizontal),
                              options: [.resetTracking, .removeExistingAnchors])
    }

    private func lockPlaneDetection() {
        sceneView.session.run(makeARConfig(planeDetection: []), options: [])
    }

    /// Config used when resuming from app background (no reset). Call from main.
    private func currentARConfig() -> ARWorldTrackingConfiguration {
        makeARConfig(planeDetection: viewModel.state == .scanning ? .horizontal : [])
    }

    private func resumeARSession() {
        guard viewIfLoaded?.window != nil else { return }
        sceneView.session.run(currentARConfig(), options: [])
    }

    private func makeARConfig(planeDetection: ARWorldTrackingConfiguration.PlaneDetection) -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = planeDetection
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        return config
    }

    // MARK: - App lifecycle (avoid GPU work in background)

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func stopObservingAppLifecycle() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func applicationDidEnterBackground() {
        guard viewIfLoaded?.window != nil else { return }
        arSessionPausedByAppBackground = true
        sceneView.session.pause()
    }

    @objc private func applicationWillEnterForeground() {
        guard arSessionPausedByAppBackground, viewIfLoaded?.window != nil else { return }
        arSessionPausedByAppBackground = false
        resumeARSession()
    }

    // MARK: - Setup

    private func setupSceneView() {
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        view = sceneView
    }

    private func setupLayout() {
        view.addSubview(surfaceScanningView)
        view.addSubview(instructionLabel)
        view.addSubview(combatHUD)

        NSLayoutConstraint.activate([
            surfaceScanningView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceScanningView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceScanningView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceScanningView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            instructionLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            instructionLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            instructionLabel.heightAnchor.constraint(equalToConstant: 44),

            combatHUD.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            combatHUD.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            combatHUD.topAnchor.constraint(equalTo: view.topAnchor),
            combatHUD.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
    }

    // MARK: - Weapon Attachment

    private func attachWeaponIfNeeded() {
        guard !weaponAttached, let pov = sceneView.pointOfView else { return }
        viewModel.sceneDirector.attachWeapon(to: pov)
        weaponAttached = true
    }

    // MARK: - Tap Handling

    @objc private func handleTap(_ r: UITapGestureRecognizer) {
        let loc = r.location(in: sceneView)

        if viewModel.state.acceptsCombatTaps {
            viewModel.handleCombatTap(at: loc, in: sceneView)
            return
        }
        if viewModel.state == .playerDefeated { return }

        guard let name = viewModel.sceneDirector.hitNodeName(at: loc, in: sceneView) else { return }
        viewModel.handleTap(on: name)
    }

    // MARK: - UI Updates

    private func showInstruction(_ text: String) {
        instructionLabel.text = text
        instructionLabel.fadeIn()
    }

    private func hideInstruction() { instructionLabel.fadeOut() }

    private func showCombatHUD() {
        UIView.animate(withDuration: 0.5) { self.combatHUD.alpha = 1 }
        combatHUD.updateBossHP(fraction: 1.0, animated: false)
        combatHUD.updatePlayerHP(current: viewModel.playerState.maxHP,
                                 max: viewModel.playerState.maxHP)
        combatHUD.updateMachineGunTimer(fraction: 0)
        combatHUD.hideRetryPrompt()
        combatHUD.hideVictoryPrompt()
    }

    private func hideCombatHUD() {
        UIView.animate(withDuration: 0.5) { self.combatHUD.alpha = 0 }
    }

    /// Delay after VO finishes before the next tip can show. Prevents overlapping popups/audio.
    private static let postVODelay: TimeInterval = 1.8
    private static let minTipDuration: TimeInterval = 3.5

    /// Duration for a tip that has voiceover: VO length + delay, so the next tip waits for audio to finish.
    private func tipDurationForVO(_ vo: AudioService.Voiceover) -> TimeInterval {
        let voLen = viewModel.audioService.voDuration(for: vo)
        return max(Self.minTipDuration, voLen + Self.postVODelay)
    }

    /// Plays a voiceover clip at most once per fight. Mirrors the one-time tip behavior.
    private func playVOOnce(_ vo: AudioService.Voiceover) {
        guard !playedVOKeys.contains(vo) else { return }
        playedVOKeys.insert(vo)
        viewModel.audioService.playVO(vo)
    }

    /// Shows a contextual tip and plays its voiceover once, sized to the VO duration.
    private func showTip(_ text: String, id: String, vo: AudioService.Voiceover) {
        combatHUD.showTip(text, id: id, duration: tipDurationForVO(vo)) { [weak self] in
            self?.playVOOnce(vo)
        }
    }

    /// Spirit chase tip is shown when we enter spiritChase; VO is delayed so it doesn't cut off boss defeat VO.
    /// Boss defeat VO starts when we transition to bossDefeated; death animation runs ~4s before we show spirit tip.
    private func scheduleSpiritChaseVO() {
        let bossDefeatDuration = viewModel.audioService.voDuration(for: .bossDefeat)
        let deathAnimationDuration: TimeInterval = 4.0
        let remainingBossDefeat = max(0, bossDefeatDuration - deathAnimationDuration)
        let delay = remainingBossDefeat + Self.postVODelay
        scheduleDelay(delay) { [weak self] in
            self?.playVOOnce(.spiritChase)
        }
    }

    /// Schedules a delayed block that is automatically cancelled on dismiss.
    private func scheduleDelay(_ delay: TimeInterval, block: @escaping () -> Void) {
        let item = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            block()
        }
        pendingDelayWork.removeAll { $0.isCancelled }
        pendingDelayWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }
}

// MARK: - ARExperienceViewModelDelegate

extension ARViewController: ARExperienceViewModelDelegate {

    func viewModel(_ vm: ARExperienceViewModel, didTransitionTo state: ARExperienceState) {
        if state.showsScanningOverlay {
            UIView.animate(withDuration: Constants.animationDuration) { self.surfaceScanningView.alpha = 1 }
        } else if state == .awaitingGrassTap {
            UIView.animate(withDuration: Constants.animationDuration) { self.surfaceScanningView.alpha = 0 }
            lockPlaneDetection()
        }

        if let text = state.instructionText {
            showInstruction(text)
        } else {
            hideInstruction()
        }

        if state.showsCombatHUD {
            showCombatHUD()
        }

        switch state {
        case .bossSpawning:
            hideInstruction()
            playVOOnce(.bossSpawn)
        case .combatActive:
            combatHUD.resetTips()
            playedVOKeys.removeAll()
            scheduleDelay(3.0) { [weak self] in
                self?.showTip("Tap to swing your sword!", id: "tap_attack", vo: .tapAttack)
            }
        case .spiritChase:
            combatHUD.updateMachineGunTimer(fraction: 0)
            combatHUD.showChaseTimer()
            let spiritDuration = tipDurationForVO(.spiritChase)
            combatHUD.showTip("Avoid the spirit. It backs off when it touches you. Survive the timer!", id: "spirit_chase", duration: max(5.0, spiritDuration)) { [weak self] in
                self?.scheduleSpiritChaseVO()
            }
            combatHUD.updateChaseTimer(secondsLeft: 20)
        case .playerDefeated:
            combatHUD.hideChaseTimer()
            combatHUD.showRetryPrompt()
            combatHUD.updateMachineGunTimer(fraction: 0)
            playVOOnce(.defeat)
        case .bossDefeated:
            playVOOnce(.bossDefeat)
        case .victory:
            combatHUD.hideChaseTimer()
            combatHUD.updateMachineGunTimer(fraction: 0)
            combatHUD.showVictoryPrompt()
            playVOOnce(.victory)
        default:
            break
        }
    }

    func viewModelDidUpdateCombat(_ vm: ARExperienceViewModel,
                                  playerHP: PlayerCombatState,
                                  bossHPFraction: Float,
                                  playerDistance: Float) {
        combatHUD.updateBossHP(fraction: bossHPFraction)
        combatHUD.updatePlayerHP(current: playerHP.currentHP, max: playerHP.maxHP)

        if playerHP.isMachineGunActive {
            combatHUD.updateMachineGunTimer(fraction: playerHP.machineGunFraction)
        }
    }

    func viewModelPlayerDidTakeDamage(_ vm: ARExperienceViewModel) {
        combatHUD.flashDamage()
        combatHUD.triggerScreenShake()
        showTip("Move away when the ground glows red!", id: "dodge", vo: .dodge)
    }

    func viewModelBossDidAttack(_ vm: ARExperienceViewModel) {
        combatHUD.triggerScreenShake()
        showTip("Watch for red circles — step back to dodge!", id: "telegraph", vo: .telegraph)
    }

    func viewModelBossDidEnterPhase(_ vm: ARExperienceViewModel, phase: BossPhase) {
        combatHUD.showPhaseTransition(phase)
        if phase == .phase2 {
            scheduleDelay(3.0) { [weak self] in
                self?.showTip("The boss is faster now — stay alert!", id: "phase2", vo: .phase2)
            }
        } else if phase == .phase3 {
            scheduleDelay(3.0) { [weak self] in
                self?.showTip("Final phase! Attack between its combos!", id: "phase3", vo: .phase3)
            }
        }
    }

    func viewModelPlayerDidHitBoss(_ vm: ARExperienceViewModel) {
        let flash = UIView(frame: view.bounds)
        flash.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        flash.isUserInteractionEnabled = false
        view.addSubview(flash)
        UIView.animate(withDuration: 0.15, animations: { flash.alpha = 0 }) { _ in
            flash.removeFromSuperview()
        }
        combatHUD.showTip("Nice hit! Get close and keep attacking!", id: "hit")
    }

    func viewModelPlayerDidSwing(_ vm: ARExperienceViewModel, isHit: Bool) {
        if !isHit {
            combatHUD.showTip("Get closer to land your strikes!", id: "miss")
        }
    }

    func viewModelPlayerDidPickupLoot(_ vm: ARExperienceViewModel, type: LootType) {
        switch type {
        case .healthPack:
            combatHUD.showPickupBanner(text: "+40 HP", color: UIColor(red: 0.1, green: 0.9, blue: 0.3, alpha: 1))
            combatHUD.flashPickup(color: .systemGreen)
        case .wizardMachineGun:
            combatHUD.showPickupBanner(text: "WIZARD GUN ACTIVE", color: UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1))
            combatHUD.flashPickup(color: UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1))
            combatHUD.updateMachineGunTimer(fraction: 1.0)
        }
    }

    func viewModelMachineGunDidExpire(_ vm: ARExperienceViewModel) {
        combatHUD.updateMachineGunTimer(fraction: 0)
        combatHUD.showPickupBanner(text: "WIZARD GUN EXPIRED", color: UIColor.white.withAlphaComponent(0.6))
    }

    func viewModelDidUpdateChase(_ vm: ARExperienceViewModel, secondsLeft: Int) {
        combatHUD.updateChaseTimer(secondsLeft: secondsLeft)
    }
}

// MARK: - ARSCNViewDelegate

extension ARViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer,
                  didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.surfaceDetected(trackerNode: node)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame else { return }
        let transform = frame.camera.transform
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.attachWeaponIfNeeded()

            switch self.viewModel.state {
            case .combatActive:
                self.viewModel.updateCameraTransform(transform)
                self.viewModel.updateCombat(atTime: time, cameraTransform: transform)
            case .spiritChase:
                self.viewModel.updateSpiritChase(atTime: time, cameraTransform: transform)
            case .bossDefeated:
                break
            default:
                break
            }

            self.updateOffScreenIndicators()
        }
    }

    private func updateOffScreenIndicators() {
        let sceneView = self.sceneView
        var spiritScreen: CGPoint?
        var bossScreen: CGPoint?

        if let spirit = viewModel.sceneDirector.spiritNode {
            spiritScreen = projectedScreenPoint(for: spirit.worldPosition, in: sceneView)
        }
        if let boss = viewModel.sceneDirector.bossNode {
            bossScreen = projectedScreenPoint(for: boss.worldPosition, in: sceneView)
        }

        combatHUD.updateOffScreenIndicators(spiritScreen: spiritScreen, bossScreen: bossScreen)
    }

    /// Projects a world position to screen coordinates, correcting for behind-camera points.
    ///
    /// `projectPoint` returns z > 1 when the point is behind the camera, and in that case
    /// x/y are perspective-flipped around screen center. We mirror them back and force the
    /// result off-screen so the indicator always appears on the correct edge.
    private func projectedScreenPoint(for worldPos: SCNVector3, in sceneView: ARSCNView) -> CGPoint {
        let projected = sceneView.projectPoint(worldPos)
        var pt = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
        if projected.z > 1.0 {
            let w = sceneView.bounds.width
            let h = sceneView.bounds.height
            pt.x = w - pt.x
            pt.y = h - pt.y
            // Guarantee off-screen so the indicator always renders for behind-camera targets.
            if pt.x >= 0 && pt.x <= w {
                pt.x = pt.x < w / 2 ? -1 : w + 1
            }
        }
        return pt
    }
}

// MARK: - ARSessionDelegate

extension ARViewController: ARSessionDelegate {}
