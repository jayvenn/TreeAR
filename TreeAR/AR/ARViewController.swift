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
///   - Bridge ARKit delegate callbacks → `ARExperienceCoordinator`.
///   - Translate coordinator state changes → UI updates.
///
/// **Non-responsibilities (what this class does NOT do):**
///   - Manage SceneKit nodes.
///   - Handle audio.
///   - Contain any game-flow logic or boolean state flags.
final class ARViewController: UIViewController {

    // MARK: - Dependencies

    private let coordinator: ARExperienceCoordinator

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

    // MARK: - Init

    init(coordinator: ARExperienceCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(coordinator:)") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupLayout()
        setupTapGesture()
        coordinator.delegate = self
        coordinator.prepare()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startARSession()
        coordinator.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
        coordinator.suspend()
    }

    // MARK: - AR Session

    private func startARSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    /// Disables further plane detection once a surface has been claimed.
    /// Reduces ARKit overhead significantly for the remainder of the experience.
    private func lockPlaneDetection() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
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

        NSLayoutConstraint.activate([
            surfaceScanningView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceScanningView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceScanningView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceScanningView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            instructionLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            instructionLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            instructionLabel.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(handleSceneViewTap(_:)))
        sceneView.addGestureRecognizer(tap)
    }

    // MARK: - Tap Handling

    @objc private func handleSceneViewTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: sceneView)
        guard let nodeName = coordinator.sceneDirector.hitNodeName(at: location,
                                                                    in: sceneView) else { return }
        coordinator.handleTap(on: nodeName)
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
}

// MARK: - ARExperienceCoordinatorDelegate

extension ARViewController: ARExperienceCoordinatorDelegate {

    func coordinator(_ coordinator: ARExperienceCoordinator,
                     didTransitionTo state: ARExperienceState) {
        // Update scanning overlay
        if state.showsScanningOverlay {
            showScanningOverlay()
        } else if state == .awaitingGrassTap {
            hideScanningOverlay()
            lockPlaneDetection()
        }

        // Update instruction label
        if let text = state.instructionText {
            showInstruction(text)
        } else if !state.showsScanningOverlay {
            hideInstruction()
        }
    }
}

// MARK: - ARSCNViewDelegate

extension ARViewController: ARSCNViewDelegate {

    /// Called on ARKit's internal thread when a new anchor is added.
    /// We dispatch to main immediately — all coordinator calls require the main thread.
    func renderer(_ renderer: SCNSceneRenderer,
                  didAdd node: SCNNode,
                  for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async { [weak self] in
            self?.coordinator.surfaceDetected(trackerNode: node)
        }
    }

    // NOTE: `renderer(_:didRenderScene:atTime:)` is intentionally NOT implemented.
    // The previous implementation dispatched to the main thread on every 60 fps frame,
    // causing substantial main-thread pressure. Plane detection via `didAdd(_:for:)` is
    // both sufficient and far more efficient.
}

// MARK: - ARSessionDelegate

extension ARViewController: ARSessionDelegate {}
