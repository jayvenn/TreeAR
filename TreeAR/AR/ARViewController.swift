//
//  ARViewController.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit
import ARKit

/// Thin presentation layer for the AR experience.
///
/// **Responsibilities (what this class does):**
///   - Own and configure the `ARSCNView`.
///   - Maintain the `instructionLabel` and `surfaceScanningView` overlays.
///   - Bridge ARKit delegate callbacks → `ARExperienceViewModel`.
///   - Translate ViewModel state changes → UI updates.
///   - Present `CombatHUDView` during boss fight states.
///
/// **Non-responsibilities (what this class does NOT do):**
///   - Manage SceneKit nodes.
///   - Handle audio.
///   - Contain any game-flow logic or boolean state flags.
final class ARViewController: UIViewController {

    // MARK: - Dependencies

    private let viewModel: ARExperienceViewModel

    // MARK: - AR

    private let sceneView = ARSCNView(frame: .zero)

    // MARK: - UI

    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment          = .center
        label.font                   = .systemFont(ofSize: 18, weight: .medium)
        label.textColor              = .secondaryLabel
        label.numberOfLines          = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor     = 0.5
        label.backgroundColor        = UIColor.white.withAlphaComponent(0.80)
        label.layer.cornerRadius     = 12
        label.layer.masksToBounds    = true
        label.alpha                  = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var surfaceScanningView: SurfaceScanningView = {
        let view = SurfaceScanningView()
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var combatHUD: CombatHUDView = {
        let hud = CombatHUDView(frame: .zero)
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.alpha = 0
        hud.isUserInteractionEnabled = true
        hud.onRetryTapped = { [weak self] in
            self?.viewModel.handleRetry()
        }
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

    /// Disables further plane detection once a surface has been claimed.
    private func lockPlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        sceneView.session.run(config, options: [])
    }

    // MARK: - Setup

    private func setupSceneView() {
        sceneView.delegate              = self
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

            instructionLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            instructionLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            instructionLabel.heightAnchor.constraint(equalToConstant: 52),

            combatHUD.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            combatHUD.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            combatHUD.topAnchor.constraint(equalTo: view.topAnchor),
            combatHUD.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(handleSceneViewTap(_:)))
        sceneView.addGestureRecognizer(tap)
    }

    // MARK: - Tap Handling

    @objc private func handleSceneViewTap(_ recognizer: UITapGestureRecognizer) {
        if viewModel.state.acceptsCombatTaps {
            viewModel.handleCombatTap()
            return
        }

        if viewModel.state == .playerDefeated {
            return
        }

        let location = recognizer.location(in: sceneView)
        guard let nodeName = viewModel.sceneDirector.hitNodeName(at: location,
                                                                  in: sceneView) else { return }
        viewModel.handleTap(on: nodeName)
    }

    // MARK: - UI Updates

    private func showInstruction(_ text: String) {
        instructionLabel.text = text
        instructionLabel.fadeIn()
    }

    private func hideInstruction() {
        instructionLabel.fadeOut()
    }

    private func showScanningOverlay() {
        UIView.animate(withDuration: animationDuration) {
            self.surfaceScanningView.alpha = 1
        }
    }

    private func hideScanningOverlay() {
        UIView.animate(withDuration: animationDuration) {
            self.surfaceScanningView.alpha = 0
        }
    }

    private func showCombatHUD() {
        UIView.animate(withDuration: 0.4) {
            self.combatHUD.alpha = 1
        }
        combatHUD.updateBossHP(fraction: 1.0, animated: false)
        combatHUD.updatePlayerHP(current: viewModel.playerState.maxHP,
                                 max: viewModel.playerState.maxHP)
        combatHUD.updateRangeIndicator(inRange: false)
        combatHUD.hideRetryPrompt()
    }

    private func hideCombatHUD() {
        UIView.animate(withDuration: 0.4) {
            self.combatHUD.alpha = 0
        }
    }
}

// MARK: - ARExperienceViewModelDelegate

extension ARViewController: ARExperienceViewModelDelegate {

    func viewModel(_ viewModel: ARExperienceViewModel,
                   didTransitionTo state: ARExperienceState) {
        if state.showsScanningOverlay {
            showScanningOverlay()
        } else if state == .awaitingGrassTap {
            hideScanningOverlay()
            lockPlaneDetection()
        }

        if let text = state.instructionText {
            showInstruction(text)
        } else if !state.showsScanningOverlay {
            hideInstruction()
        }

        if state.showsCombatHUD {
            showCombatHUD()
        }

        switch state {
        case .playerDefeated:
            combatHUD.showRetryPrompt()
        case .victory:
            schedule(after: 3.0) { [weak self] in
                self?.hideCombatHUD()
            }
        default:
            break
        }
    }

    func viewModelDidUpdateCombat(_ viewModel: ARExperienceViewModel,
                                  playerHP: PlayerCombatState,
                                  bossHPFraction: Float,
                                  playerDistance: Float) {
        combatHUD.updateBossHP(fraction: bossHPFraction)
        combatHUD.updatePlayerHP(current: playerHP.currentHP, max: playerHP.maxHP)
        combatHUD.updateRangeIndicator(inRange: playerDistance <= playerHP.attackRange)
    }

    func viewModelPlayerDidTakeDamage(_ viewModel: ARExperienceViewModel) {
        combatHUD.flashDamage()
    }

    func viewModelBossDidEnterPhase(_ viewModel: ARExperienceViewModel, phase: BossPhase) {
        combatHUD.showPhaseTransition(phase)
    }

    private func schedule(after delay: TimeInterval, block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }
}

// MARK: - ARSCNViewDelegate

extension ARViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer,
                  didAdd node: SCNNode,
                  for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.surfaceDetected(trackerNode: node)
        }
    }

    /// Called on SceneKit's renderer thread every frame (~60 Hz).
    /// We capture the camera transform here and dispatch all logic to main.
    /// The state check is inside the `main.async` block so we never read
    /// ViewModel properties from the renderer thread (avoids data races).
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = sceneView.session.currentFrame else { return }
        let transform = frame.camera.transform
        DispatchQueue.main.async { [weak self] in
            guard let self, self.viewModel.state == .combatActive else { return }
            self.viewModel.updateCameraTransform(transform)
            self.viewModel.updateCombat(atTime: time, cameraTransform: transform)
        }
    }
}

// MARK: - ARSessionDelegate

extension ARViewController: ARSessionDelegate {}
