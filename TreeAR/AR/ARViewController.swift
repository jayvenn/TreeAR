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
        hud.onRetryTapped = { [weak self] in self?.viewModel.handleRetry() }
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
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
        viewModel.suspend()
    }

    // MARK: - AR Session

    private func startARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    private func lockPlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        sceneView.session.run(config, options: [])
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

    /// Plays a voiceover clip at most once per fight. Mirrors the one-time tip behavior.
    private func playVOOnce(_ vo: AudioService.Voiceover) {
        guard !playedVOKeys.contains(vo) else { return }
        playedVOKeys.insert(vo)
        viewModel.audioService.playVO(vo)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.combatHUD.showTip("Tap to swing your sword!", id: "tap_attack")
                self?.playVOOnce(.tapAttack)
            }
        case .spiritChase:
            combatHUD.updateMachineGunTimer(fraction: 0)
            combatHUD.showChaseTimer()
            combatHUD.showTip("Avoid the spirit. It backs off when it touches you. Survive the timer!", id: "spirit_chase", duration: 5.0)
            combatHUD.updateChaseTimer(secondsLeft: 20)
            playVOOnce(.spiritChase)
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
        combatHUD.showTip("Move away when the ground glows red!", id: "dodge")
        playVOOnce(.dodge)
    }

    func viewModelBossDidAttack(_ vm: ARExperienceViewModel) {
        combatHUD.triggerScreenShake()
        combatHUD.showTip("Watch for red circles — step back to dodge!", id: "telegraph")
        playVOOnce(.telegraph)
    }

    func viewModelBossDidEnterPhase(_ vm: ARExperienceViewModel, phase: BossPhase) {
        combatHUD.showPhaseTransition(phase)
        if phase == .phase2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.combatHUD.showTip("The boss is faster now — stay alert!", id: "phase2")
                self?.playVOOnce(.phase2)
            }
        } else if phase == .phase3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.combatHUD.showTip("Final phase! Attack between its combos!", id: "phase3")
                self?.playVOOnce(.phase3)
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
            default:
                break
            }
        }
    }
}

// MARK: - ARSessionDelegate

extension ARViewController: ARSessionDelegate {}
