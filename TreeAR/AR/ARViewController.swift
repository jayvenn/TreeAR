//
//  ARViewController.swift
//  TreeAR
//
//  AR experience - Plant a seed, watch it grow into a tree!
//

import UIKit
import ARKit
import AVFoundation
import SceneKit

class ARViewController: UIViewController {
    
    // MARK: - Properties
    let sceneView = ARSCNView(frame: .zero)
    let rainParticleSystem = SCNParticleSystem.rain
    
    let rainView: UIView = {
        let view = UIView()
        view.backgroundColor = .transparentTextBackgroundBlack
        return view
    }()
    
    let seedNode = SCNNode.seed
    let hole1Node = SCNNode.hole1
    let hole2Node = SCNNode.hole2
    let hole3Node = SCNNode.hole3
    let floorPlaneNode = SCNNode.floorPlane
    let treeNode = SCNNode.tree
    let applesNode = SCNNode.apples
    let cloudNode = SCNNode.cloud
    
    let seedYDistance: Float = 0.2
    
    let alphaToZeroAction = SCNAction.fadeOpacity(to: 0, duration: 0.5)
    let alphaToOneAction = SCNAction.fadeOpacity(to: 1, duration: 0)
    
    let holeNodeYAllevation: Float = 2 * scaleFactor
    
    lazy var appleNames: [String] = {
        var names = [String]()
        for node in applesNode.childNodes {
            if let name = node.name {
                names.append(name)
            }
        }
        return names
    }()
    
    lazy var sunnyWeatherPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "SunnyWeather", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = -1
        player.volume = 1
        player.prepareToPlay()
        return player
    }()
    
    lazy var rainyWeatherPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "RainyWeather", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1
        player.numberOfLoops = -1
        player.prepareToPlay()
        return player
    }()
    
    lazy var rainPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "Rain", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 0.5
        player.numberOfLoops = -1
        player.prepareToPlay()
        return player
    }()
    
    lazy var postIntroduction1Player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "name", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1
        player.prepareToPlay()
        return player
    }()
    
    lazy var postIntroduction2Player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "oxygen", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1
        player.prepareToPlay()
        return player
    }()
    
    lazy var postIntroduction3Player: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "thanks", withExtension: "m4a"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.volume = 1
        player.prepareToPlay()
        return player
    }()
    
    lazy var instructionLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.text = "Move around to find a surface\nto plant your seed"
        label.textAlignment = .center
        label.font = DesignSystem.Typography.subheadline
        label.textColor = DesignSystem.Colors.textSecondary
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 2
        label.minimumScaleFactor = 0.7
        label.backgroundColor = DesignSystem.Colors.overlayBlur
        label.layer.cornerRadius = DesignSystem.Radius.md
        label.layer.masksToBounds = true
        label.layer.borderWidth = 1
        label.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
        label.contentInsets = UIEdgeInsets(top: DesignSystem.Spacing.md, left: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.md, right: DesignSystem.Spacing.lg)
        return label
    }()
    
    var instructionLabelHeightConstraint: NSLayoutConstraint?
    
    lazy var plantButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Plant Seed", for: .normal)
        button.titleLabel?.font = DesignSystem.Typography.headline
        button.addTarget(self, action: #selector(ARViewController.plantSeedButtonDidTouch(_:)), for: .touchUpInside)
        button.setTitleColor(.white, for: .normal)
        button.alpha = 0
        button.layer.cornerRadius = DesignSystem.Radius.lg
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = DesignSystem.Colors.primary
        button.contentEdgeInsets = UIEdgeInsets(top: DesignSystem.Spacing.md, left: DesignSystem.Spacing.xl, bottom: DesignSystem.Spacing.md, right: DesignSystem.Spacing.xl)
        DesignSystem.Shadow.applySubtle(to: button)
        return button
    }()
    
    var viewModel: ARViewModel!
    
    override func loadView() {
        super.loadView()
        setUpSceneView()
        resetTrackingConfiguration()
        setUpLayouts()
        animateIntroductionScene()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDismissButton()
    }
    
    private func setupDismissButton() {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.titleLabel?.font = DesignSystem.Typography.subheadline
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = DesignSystem.Colors.overlayDark
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = DesignSystem.Radius.sm
        button.contentEdgeInsets = UIEdgeInsets(top: DesignSystem.Spacing.sm, left: DesignSystem.Spacing.md, bottom: DesignSystem.Spacing.sm, right: DesignSystem.Spacing.md)
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignSystem.Spacing.sm),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.md)
        ])
    }
    
    @objc func backTapped() {
        viewModel.dismiss()
    }
    
    func computeHolePosition(vector3: SCNVector3) -> SCNVector3 {
        var position = vector3
        position.y -= holeNodeYAllevation
        return position
    }
    
    func computeGamePosition(vector3: SCNVector3) -> SCNVector3 {
        var position = vector3
        position.y += holeNodeYAllevation
        return position
    }
}

// MARK: - ARViewController Animation
extension ARViewController {
    
    func seedPlacementAnimation() {
        postIntroduction2Player?.play()
        UIView.animate(withDuration: 1, animations: {
            self.instructionLabel.alpha = 0
            self.plantButton.alpha = 0
        }) { _ in
            self.instructionLabel.isHidden = true
            self.plantButton.removeFromSuperview()
            self.openHoleAnimation()
        }
    }
    
    var fadeInAndOutSequenceAction: SCNAction {
        .sequence([
            .fadeOpacity(to: 1, duration: 1),
            .wait(duration: 2),
            .fadeOpacity(to: 0, duration: 0)
        ])
    }
    
    var fadeInSequenceAction: SCNAction {
        .sequence([
            .fadeOpacity(to: 1, duration: 1),
            .wait(duration: 2)
        ])
    }
    
    var fadeOutSequenceAction: SCNAction {
        .sequence([
            .fadeOpacity(to: 0, duration: 1)
        ])
    }
    
    var waitSequenceAction: SCNAction {
        .sequence([.wait(duration: 1)])
    }
    
    var longWaitSequenceAction: SCNAction {
        .sequence([.wait(duration: 3)])
    }
    
    var veryLongWaitSequenceAction: SCNAction {
        .sequence([.wait(duration: 6)])
    }
    
    var moveBackAndForthSequenceAction: SCNAction {
        .sequence([
            SCNAction.moveBy(x: 0, y: 0, z: -1, duration: 3),
            SCNAction.moveBy(x: 0, y: 0, z: 2, duration: 6),
            SCNAction.moveBy(x: 0, y: 0, z: -1, duration: 3)
        ])
    }
    
    func growInSizeSequenceAction(_ node: SCNNode) -> SCNAction {
        let baseScale = node.scale.y  // Use y as uniform scale reference
        let scale1 = CGFloat(baseScale * 0.1)
        let scale2 = CGFloat(baseScale * 0.4)
        let scale3 = CGFloat(baseScale * 0.3)
        let scale4 = CGFloat(baseScale * 0.7)
        let scale5 = CGFloat(baseScale * 0.6)
        let scale6 = CGFloat(baseScale * 1.1)
        let scale7 = CGFloat(baseScale * 1.0)
        
        return .sequence([
            SCNAction.scale(to: scale1, duration: 0),
            SCNAction.fadeIn(duration: 1),
            SCNAction.scale(to: scale2, duration: 1.5),
            SCNAction.scale(to: scale3, duration: 0.5),
            SCNAction.scale(to: scale4, duration: 1.5),
            SCNAction.scale(to: scale5, duration: 0.5),
            SCNAction.scale(to: scale6, duration: 1.5),
            SCNAction.scale(to: scale7, duration: 0.5)
        ])
    }
    
    func openHoleAnimation() {
        let position = viewModel.gamePosition
        hole1Node.position = computeHolePosition(vector3: position)
        hole2Node.position = computeHolePosition(vector3: position)
        
        hole1Node.opacity = 0
        hole2Node.opacity = 0
        hole3Node.opacity = 0
        
        addNodesToSceneView(nodes: [hole1Node, hole2Node])
        hole3Node.runAction(fadeInAndOutSequenceAction) {
            self.hole2Node.runAction(self.fadeInAndOutSequenceAction) {
                self.hole1Node.runAction(self.fadeInSequenceAction) {
                    let action = SCNAction.moveBy(x: 0, y: -CGFloat(self.seedYDistance), z: 0, duration: 2)
                    action.timingMode = .easeIn
                    self.seedNode.runAction(action) {
                        self.closeHoleAnimation()
                    }
                }
            }
        }
    }
    
    func closeHoleAnimation() {
        hole1Node.runAction(fadeInAndOutSequenceAction) {
            self.hole2Node.runAction(self.fadeInAndOutSequenceAction) {
                self.hole3Node.runAction(self.fadeInSequenceAction) {
                    self.hole3Node.runAction(self.fadeOutSequenceAction)
                    self.seedNode.runAction(self.fadeOutSequenceAction) {
                        self.hole1Node.removeFromParentNode()
                        self.hole2Node.removeFromParentNode()
                        self.hole3Node.removeFromParentNode()
                        DispatchQueue.main.async {
                            self.growIntoFlowerAnimation()
                        }
                    }
                }
            }
        }
    }
    
    func growIntoFlowerAnimation() {
        postIntroduction3Player?.play()
        let holeAndLeaf1Node = SCNNode.holeAndLeaf1
        let holeAndLeaf2Node = SCNNode.holeAndLeaf2
        let holeAndLeaf3Node = SCNNode.holeAndLeaf3
        
        let position = viewModel.gamePosition
        holeAndLeaf1Node.position = computeHolePosition(vector3: position)
        holeAndLeaf2Node.position = computeHolePosition(vector3: position)
        holeAndLeaf3Node.position = computeHolePosition(vector3: position)
        
        holeAndLeaf1Node.opacity = 0
        holeAndLeaf2Node.opacity = 0
        holeAndLeaf3Node.opacity = 0
        
        holeAndLeaf3Node.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        
        sceneView.scene.rootNode.addChildNode(holeAndLeaf1Node)
        
        cloudNode.position = viewModel.gamePosition
        cloudNode.position.y += 2.0
        cloudNode.opacity = 0
        
        rainParticleSystem.colliderNodes = [floorPlaneNode, holeAndLeaf1Node, holeAndLeaf2Node, holeAndLeaf3Node]
        
        holeAndLeaf1Node.runAction(fadeInAndOutSequenceAction) {
            self.sceneView.scene.rootNode.addChildNode(holeAndLeaf2Node)
            holeAndLeaf2Node.runAction(self.fadeInAndOutSequenceAction) {
                self.sceneView.scene.rootNode.addChildNode(holeAndLeaf3Node)
                holeAndLeaf3Node.runAction(self.fadeInSequenceAction) {
                    self.sceneView.scene.rootNode.addChildNode(self.cloudNode)
                    self.cloudNode.addParticleSystem(self.rainParticleSystem)
                    self.cloudNode.runAction(self.fadeInSequenceAction) {
                        self.cloudNode.runAction(self.veryLongWaitSequenceAction) {
                            holeAndLeaf3Node.runAction(self.fadeOutSequenceAction) {
                                holeAndLeaf1Node.removeFromParentNode()
                                holeAndLeaf2Node.removeFromParentNode()
                                holeAndLeaf3Node.removeFromParentNode()
                                self.cloudNode.removeAllParticleSystems()
                                DispatchQueue.main.async {
                                    self.growIntoATree()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func growIntoATree() {
        sunnyWeatherPlayer?.play()
        
        let position = viewModel.gamePosition
        treeNode.position = position
        applesNode.position = position
        
        treeNode.opacity = 0
        applesNode.opacity = 0
        
        sceneView.scene.rootNode.addChildNode(treeNode)
        sceneView.scene.rootNode.addChildNode(applesNode)
        
        let moveUpAction = SCNAction.moveBy(x: 0, y: 1, z: 0, duration: 3)
        let foreverAction = SCNAction.repeatForever(moveBackAndForthSequenceAction)
        
        cloudNode.runAction(moveUpAction) {
            self.cloudNode.runAction(foreverAction)
        }
        
        let scalingAction = growInSizeSequenceAction(treeNode)
        treeNode.runAction(scalingAction) {
            self.treeNode.runAction(self.fadeInSequenceAction) {
                self.applesNode.runAction(self.waitSequenceAction) {
                    self.applesNode.runAction(self.fadeInSequenceAction) {
                        self.applesNode.runAction(self.longWaitSequenceAction) {
                            DispatchQueue.main.async {
                                self.appleDropFromTree()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func appleDropFromTree() {
        let appleNodeName = "apple8"
        for node in applesNode.childNodes {
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ARViewController.didTap(withGestureRecognizer:)))
            sceneView.addGestureRecognizer(tapGestureRecognizer)
            if node.name == appleNodeName {
                DispatchQueue.main.async {
                    self.animateAppleNode(node: node)
                    self.noteForApple()
                }
            }
        }
    }
    
    @objc func didTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation)
        
        guard let node = hitTestResults.first?.node else { return }
        animateAppleNode(node: node)
    }
    
    func animateAppleNode(node: SCNNode) {
        guard let name = node.name,
              appleNames.contains(name),
              !node.hasActions
        else { return }
        
        let originalPosition = node.position
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: nil)
        let moveToPositionAction = SCNAction.move(to: originalPosition, duration: 1)
        
        DispatchQueue.main.async {
            node.physicsBody = physicsBody
            node.runAction(self.veryLongWaitSequenceAction) {
                node.runAction(self.fadeOutSequenceAction) {
                    node.physicsBody = nil
                    node.position = originalPosition
                    node.runAction(moveToPositionAction) {
                        node.runAction(self.fadeInSequenceAction) {}
                    }
                }
            }
        }
    }
    
    func noteForApple() {
        instructionLabel.numberOfLines = 5
        instructionLabel.font = DesignSystem.Typography.footnote
        instructionLabel.isHidden = false
        instructionLabel.alpha = 1
        instructionLabelHeightConstraint?.constant = 120
        
        let when1 = DispatchTime.now()
        DispatchQueue.main.asyncAfter(deadline: when1) {
            let text = "You can tap on an Apple to have a closer look at it on the ground! Check out the Apples!"
            self.instructionLabel.text = text
            let when2 = DispatchTime.now() + 18
            DispatchQueue.main.asyncAfter(deadline: when2) {
                let text = "I hope you have enjoyed the Playground!\nI would like to talk with passionate developers, engage in great conversations with Apple experts, try out new technologies, attend awesome events, and share the best memories with everyone at WWDC18!"
                self.instructionLabel.text = text
            }
        }
    }
    
    func animateIntroductionScene() {
        postIntroduction1Player?.play()
        UIView.animate(withDuration: 1, animations: {
            self.instructionLabel.alpha = 1
            self.plantButton.alpha = 1
        })
    }
}

// MARK: - ARViewController IBAction Methods
extension ARViewController {
    @objc func plantSeedButtonDidTouch(_ sender: UIButton) {
        let computedPosition = computeGamePosition(vector3: hole3Node.position)
        guard viewModel.plantSeed(at: computedPosition) else { return }
        
        let physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorPlaneNode.physicsBody = physicsBody
        floorPlaneNode.position = viewModel.gamePosition
        sceneView.scene.rootNode.addChildNode(floorPlaneNode)
        
        seedPlacementAnimation()
    }
}

// MARK: - ARViewController Set Up and Layouts
extension ARViewController {
    func setUpSceneView() {
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session = ARSession()
        sceneView.delegate = self
        view = sceneView
    }
    
    func setUpLayouts() {
        setUpInstructionLabelLayouts()
        setUpPlantButtonLayouts()
    }
    
    func setUpInstructionLabelLayouts() {
        view.addSubview(instructionLabel)
        let safe = view.safeAreaLayoutGuide
        instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.md).isActive = true
        instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.md).isActive = true
        instructionLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: DesignSystem.Spacing.md).isActive = true
        instructionLabelHeightConstraint = instructionLabel.heightAnchor.constraint(equalToConstant: 64)
        instructionLabelHeightConstraint?.isActive = true
    }
    
    func setUpPlantButtonLayouts() {
        view.addSubview(plantButton)
        let safe = view.safeAreaLayoutGuide
        plantButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignSystem.Spacing.lg).isActive = true
        plantButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignSystem.Spacing.lg).isActive = true
        plantButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -DesignSystem.Spacing.lg).isActive = true
        plantButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }
    
    func resetTrackingConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        sceneView.session.run(configuration, options: options)
    }
}

// MARK: - ARViewController SceneKit / AR Delegate
extension ARViewController {
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard !viewModel.gameStarted,
              let hitTestResult = sceneView.hitTest(
                CGPoint(x: view.frame.midX, y: view.frame.midY),
                types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane]
              ).first
        else { return }
        
        DispatchQueue.main.async {
            let translation = hitTestResult.worldTransform.translation
            let position = self.vector(from: translation)
            self.hole3Node.position = self.computeHolePosition(vector3: position)
            self.seedNode.position = SCNVector3(
                self.hole3Node.position.x,
                self.hole3Node.position.y + self.seedYDistance,
                self.hole3Node.position.z
            )
            if !self.viewModel.foundSurface {
                self.viewModel.surfaceFound(at: position)
                self.sceneView.scene.rootNode.addChildNode(self.hole3Node)
                self.sceneView.scene.rootNode.addChildNode(self.seedNode)
            }
        }
    }
}

extension ARViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {}
    
    func update(_ node: inout SCNNode, withGeometry geometry: SCNGeometry, type: SCNPhysicsBodyType) {
        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: type, shape: shape)
        node.physicsBody = physicsBody
    }
}

extension ARViewController: ARSessionDelegate {}

extension ARViewController {
    func addNodesToSceneView(nodes: [SCNNode]) {
        for node in nodes {
            sceneView.scene.rootNode.addChildNode(node)
        }
    }
    
    func centerExtentVector(from planeAnchor: ARPlaneAnchor) -> SCNVector3 {
        SCNVector3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
    }
    
    func vector(from translation: SIMD3<Float>) -> SCNVector3 {
        SCNVector3(translation.x, translation.y, translation.z)
    }
    
    func cameraVectors() -> (SCNVector3, SCNVector3)? {
        guard let frame = sceneView.session.currentFrame else { return nil }
        let transform = SCNMatrix4(frame.camera.transform)
        let directionFactor: Float = -5
        let direction = SCNVector3(
            directionFactor * transform.m31,
            directionFactor * transform.m32,
            directionFactor * transform.m33
        )
        let position = SCNVector3(transform.m41, transform.m42, transform.m43)
        return (direction, position)
    }
}

// MARK: - simd_float4x4 translation extension
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

