//
//  ARViewController.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import UIKit
import ARKit
import AVFoundation

final class ARViewController: UIViewController {

    // MARK: - Scene nodes
    let sceneView    = ARSCNView(frame: CGRect(x: 0, y: 0, width: 500, height: 600))
    let grassNode    = SCNNode.grass
    let magicBoxNode = SCNNode.magicBox
    var trackerNode  = SCNNode()

    // MARK: - State
    var foundSurface   = false
    var gameStarted    = false
    var grassTapped    = false
    var magicBoxOpened = false

    private let coverYPosition:        Float = 0.1
    private let presentationYPosition: Float = 0.5

    lazy var instructionLabelHeightConstraint: NSLayoutConstraint =
        instructionLabel.heightAnchor.constraint(equalToConstant: 52)

    // MARK: - Speech
    enum SpeechString: String {
        case coding = "Coding is a superpower. Coding empowers people to do incredible things. Hope you like it."
    }

    private let speechSynthesizer = AVSpeechSynthesizer()

    private func speakWith(speechString: SpeechString) {
        let utterance = AVSpeechUtterance(string: speechString.rawValue)
        utterance.pitchMultiplier = 1.2
        utterance.rate = 0.4
        speechSynthesizer.speak(utterance)
    }

    // MARK: - UIKit
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "MOVE AROUND TO\nSEE WHAT YOU CAN FIND!"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .lightGray
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 2
        label.minimumScaleFactor = 0.5
        label.backgroundColor = .transparentTextBackgroundWhite
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        return label
    }()

    private let yBillboardConstraint: SCNBillboardConstraint = {
        let c = SCNBillboardConstraint()
        c.freeAxes = .Y
        return c
    }()

    private let surfaceScanningView: SurfaceScanningView = {
        let view = SurfaceScanningView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()

    // MARK: - Audio (all optional – gracefully silent if a file is missing)
    private let audioExt = "m4a"

    private func makePlayer(resource: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: audioExt),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    private lazy var scene1AudioPlayer = makePlayer(resource: "Move around")
    private lazy var scene2AudioPlayer = makePlayer(resource: "Something is moving")
    private lazy var scene3AudioPlayer = makePlayer(resource: "Whoa")
    private lazy var backgroundAudioPlayer: AVAudioPlayer? = {
        guard let p = makePlayer(resource: "SunnyWeather") else { return nil }
        p.numberOfLoops = -1
        p.volume = 0.2
        return p
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpSceneView()
        setUpIntroductionLayout()
        animateIntroductionScene()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startInitialScanning()
        backgroundAudioPlayer?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Setup
    private func setUpSceneView() {
        sceneView.session = ARSession()
        sceneView.delegate = self
        view = sceneView
    }

    private func resetTrackingConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Layouts
    private func setUpIntroductionLayout() {
        view.addSubview(surfaceScanningView)
        NSLayoutConstraint.activate([
            surfaceScanningView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceScanningView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceScanningView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceScanningView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.addSubview(instructionLabel)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            instructionLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            instructionLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            instructionLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            instructionLabelHeightConstraint
        ])
    }

    // MARK: - Scene 1: introduction overlay
    private func startInitialScanning() {
        scene1AudioPlayer?.volume = 1
        scene1AudioPlayer?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.resetTrackingConfiguration()
        }
    }

    func animateIntroductionScene() {
        UIView.animate(withDuration: animationDuration) {
            self.instructionLabel.alpha = 1
            self.surfaceScanningView.alpha = 1
        }
    }

    // MARK: - Scene 2: surface found
    private func removeSurfaceScanningView() {
        UIView.animate(withDuration: animationDuration, animations: {
            self.surfaceScanningView.alpha = 0
        }, completion: { _ in
            self.surfaceScanningView.removeFromSuperview()
            self.addGrassToScene()
        })
    }

    // MARK: - Scene 3: grass grows
    private func addGrassToScene() {
        let lightsNode   = SCNNode.lights
        let growAction   = SCNAction.grassGrowSequenceAction(grassNode)
        let rotateAction = SCNAction.grassesRotation
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []

        scene2AudioPlayer?.volume = 1
        scene2AudioPlayer?.play()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.sceneView.session.run(configuration, options: [])
            self.trackerNode.addChildNode(self.grassNode)
            self.grassNode.runAction(growAction) { [weak self] in
                self?.addTapGestureToSceneView()
            }
            for child in self.grassNode.childNodes { child.runAction(rotateAction) }
            self.trackerNode.addChildNode(lightsNode)
        }
    }

    private func addTapGestureToSceneView() {
        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(didTapSceneView(withGestureRecognizer:)))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.instructionLabel.text = "TAP ON THE GRASS\nTO SEE WHAT'S AROUND."
            self.instructionLabel.fadeIn()
            self.sceneView.addGestureRecognizer(tap)
        }
    }

    @objc func didTapSceneView(withGestureRecognizer recognizer: UITapGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hits = sceneView.hitTest(tapLocation)
        guard instructionLabel.alpha == 1,
              let node = hits.first?.node,
              let nodeName = node.name else { return }

        switch nodeName {
        case "grass":
            instructionLabel.fadeOut()
            shrinkGrass()
        case "base", "cover":
            instructionLabel.fadeOut()
            openMagicBox()
        default:
            return
        }
    }

    // MARK: - Scene 4: shrink grass & show box
    private func shrinkGrass() {
        guard !grassTapped else { return }
        grassTapped = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.grassNode.runAction(.grassShrinkSequenceAction(self.grassNode))
            self.grassNode.runAction(.grassShrinkFadeOutSequenceAction())
            for child in self.grassNode.childNodes { child.runAction(.grassReversedRotation) }
            self.showMagicBox()
        }
    }

    private func showMagicBox() {
        magicBoxNode.constraints = [yBillboardConstraint]
        DispatchQueue.main.async {
            self.trackerNode.addChildNode(self.magicBoxNode)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.instructionLabel.text = "TAP ON THE BOX\nTO OPEN UP THE BOX."
                self.instructionLabel.fadeIn()
            }
            self.scene3AudioPlayer?.volume = 1
            self.scene3AudioPlayer?.play()
            self.magicBoxNode.constraints = []
            self.magicBoxNode.runAction(.fadeInSequenceAction)
        }
    }

    // MARK: - Scene 5: open box
    private func openMagicBox() {
        guard !magicBoxOpened,
              let mainNode    = magicBoxNode.childNode(withName: "main",       recursively: true),
              let coverNode   = mainNode.childNode(withName: "cover",          recursively: true),
              let spinnerNode = mainNode.childNode(withName: "spinner",        recursively: true),
              let sideStars   = mainNode.childNode(withName: "side_stars",     recursively: true),
              let mainStars   = mainNode.childNode(withName: "main_stars",     recursively: true)
        else { return }
        magicBoxOpened = true

        let dur: TimeInterval = 0.3
        let coverSeq = SCNAction.sequence([
            SCNAction.move(to: SCNVector3(0, coverYPosition, 0),     duration: dur),
            SCNAction.move(to: SCNVector3(0, coverYPosition, -0.22), duration: dur),
            SCNAction.move(to: SCNVector3(0, -0.1,           -0.25), duration: dur)
        ])
        let spinForever = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 1)
        )

        DispatchQueue.main.async {
            mainStars.runAction(.fadeIn(duration: 1))
            sideStars.runAction(.fadeOutSequenceAction)
            spinnerNode.runAction(spinForever)
            coverNode.runAction(coverSeq) {
                self.showGuardian(mainNode: mainNode)
            }
        }
    }

    // MARK: - Scene 6: guardian rises, speaks, returns
    private func showGuardian(mainNode: SCNNode) {
        guard let guardian = mainNode.childNode(withName: "guardian", recursively: true) else { return }
        let original = guardian.position
        var raised = original
        raised.y = presentationYPosition
        let moveUp = SCNAction.move(to: raised, duration: 4)
        moveUp.timingMode = .easeIn

        DispatchQueue.main.async {
            guardian.runAction(.fadeIn(duration: 1))
            guardian.runAction(moveUp) { self.speakWith(speechString: .coding) }
        }
        hideGuardian(guardian: guardian, originalPosition: original)
    }

    private func hideGuardian(guardian: SCNNode, originalPosition: SCNVector3) {
        let hideSeq = SCNAction.sequence([
            SCNAction.move(to: originalPosition, duration: 4),
            SCNAction.fadeOut(duration: 0.5)
        ])
        hideSeq.timingMode = .easeOut
        DispatchQueue.main.asyncAfter(deadline: .now() + 16) {
            guardian.runAction(hideSeq) {
                // Guardian has returned — ready for the next chapter.
            }
        }
    }

    // MARK: - Helpers
    func cameraVectors() -> (direction: simd_float3, position: simd_float3)? {
        guard let frame = sceneView.session.currentFrame else { return nil }
        let t = frame.camera.transform
        return (simd_make_float3(t[2]) * -5, simd_make_float3(t[3]))
    }
}

// MARK: - ARSCNViewDelegate
extension ARViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.handleSceneRendering()
        }
    }

    func handleSceneRendering() {
        guard !gameStarted,
              sceneView.hitTest(
                CGPoint(x: view.frame.midX, y: view.frame.midY),
                types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane]
              ).first != nil
        else { return }
        foundSurface = true
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor, !gameStarted else { return }
        DispatchQueue.main.async {
            self.instructionLabel.fadeOut()
            self.gameStarted = true
            self.trackerNode = node
            self.removeSurfaceScanningView()
        }
    }
}

// MARK: - ARSessionDelegate
extension ARViewController: ARSessionDelegate {}
