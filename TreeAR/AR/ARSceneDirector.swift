//
//  ARSceneDirector.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit
import ARKit

/// Owns and orchestrates every SceneKit node for the AR experience.
///
/// **Threading contract:** All public methods must be called from the **main thread**.
/// Completion handlers are always delivered on the main thread.
///
/// **Ownership model:** Nodes are created once via lazy properties.
/// Once added to the scene graph they are retained by SceneKit; this class
/// keeps a weak reference to the tracker node to avoid retain cycles with ARKit.
final class ARSceneDirector {

    // MARK: - Private constants

    private enum Constant {
        static let coverY: Float        = 0.1
        static let presentationY: Float = 0.5
        static let boxRevealDelay: TimeInterval = 2.0
        static let boxTapHintDelay: TimeInterval = 10.0
        static let guardianHideDuration: TimeInterval = 16.0
    }

    private enum NodeName {
        static let main      = "main"
        static let cover     = "cover"
        static let spinner   = "spinner"
        static let sideStars = "side_stars"
        static let mainStars = "main_stars"
        static let guardian  = "guardian"
    }

    // MARK: - Pre-loaded nodes (lazy — loaded once, warm on first access)

    private lazy var grassNode:    SCNNode = .grass
    private lazy var magicBoxNode: SCNNode = .magicBox
    private lazy var lightsNode:   SCNNode = .lights

    // MARK: - Runtime state

    private weak var trackerNode: SCNNode?
    private var guardianOriginalPosition: SCNVector3?
    private weak var activeGuardian: SCNNode?

    private let yBillboardConstraint: SCNBillboardConstraint = {
        let c = SCNBillboardConstraint()
        c.freeAxes = .Y
        return c
    }()

    // MARK: - Setup

    /// Pre-warm lazy node loading on a background thread to prevent frame hitches
    /// when the experience begins. Safe to call from any thread.
    func preloadAssets() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            _ = self.grassNode
            _ = self.magicBoxNode
            _ = self.lightsNode
        }
    }

    /// Must be called once a surface is found, before any other scene methods.
    func configure(trackerNode: SCNNode) {
        assertMainThread()
        self.trackerNode = trackerNode
    }

    // MARK: - Phase 1: Grass

    /// Adds grass to the scene and runs the grow animation.
    /// `completion` is called on the main thread when the animation finishes.
    func growGrass(completion: @escaping () -> Void) {
        assertMainThread()
        guard let tracker = trackerNode else { return }

        tracker.addChildNode(grassNode)
        tracker.addChildNode(lightsNode)

        for child in grassNode.childNodes {
            child.runAction(.grassesRotation)
        }
        grassNode.runAction(.grassGrowSequenceAction(grassNode), completionHandler: completion)
    }

    // MARK: - Phase 2: Dismiss grass & reveal box

    /// Shrinks grass then calls `completion` once it's safe to add the magic box.
    func dismissGrass(completion: @escaping () -> Void) {
        assertMainThread()
        grassNode.runAction(.grassShrinkSequenceAction(grassNode))
        grassNode.runAction(.grassShrinkFadeOutSequenceAction())
        for child in grassNode.childNodes { child.runAction(.grassReversedRotation) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: completion)
    }

    /// Adds the magic box with a billboard constraint, waits for it to settle,
    /// then fades it in and calls `onReady`.
    func presentMagicBox(onReady: @escaping () -> Void) {
        assertMainThread()
        guard let tracker = trackerNode else { return }

        magicBoxNode.constraints = [yBillboardConstraint]
        tracker.addChildNode(magicBoxNode)

        DispatchQueue.main.asyncAfter(deadline: .now() + Constant.boxRevealDelay) { [weak self] in
            guard let self else { return }
            self.magicBoxNode.constraints = []
            self.magicBoxNode.runAction(.fadeInSequenceAction)
            onReady()
        }
    }

    // MARK: - Phase 3: Open box

    /// Animates the box opening sequence.
    /// `completion` receives the `mainNode` sub-tree that contains the guardian.
    func openMagicBox(completion: @escaping (SCNNode) -> Void) {
        assertMainThread()

        guard
            let mainNode    = magicBoxNode.childNode(withName: NodeName.main,      recursively: true),
            let coverNode   = mainNode.childNode(withName: NodeName.cover,         recursively: true),
            let spinnerNode = mainNode.childNode(withName: NodeName.spinner,       recursively: true),
            let sideStars   = mainNode.childNode(withName: NodeName.sideStars,     recursively: true),
            let mainStars   = mainNode.childNode(withName: NodeName.mainStars,     recursively: true)
        else { return }

        let d: TimeInterval = 0.3
        let coverSeq = SCNAction.sequence([
            .move(to: SCNVector3(0, Constant.coverY,  0),    duration: d),
            .move(to: SCNVector3(0, Constant.coverY, -0.22), duration: d),
            .move(to: SCNVector3(0, -0.1,            -0.25), duration: d)
        ])
        let spinForever = SCNAction.repeatForever(
            .rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: 1)
        )

        mainStars.runAction(.fadeIn(duration: 1))
        sideStars.runAction(.fadeOutSequenceAction)
        spinnerNode.runAction(spinForever)
        coverNode.runAction(coverSeq) { completion(mainNode) }
    }

    // MARK: - Phase 4: Guardian

    /// Raises the guardian to presentation height.
    /// `completion` fires when the rise animation completes (speech starts here).
    func raiseGuardian(from mainNode: SCNNode, completion: @escaping () -> Void) {
        assertMainThread()

        guard let guardian = mainNode.childNode(withName: NodeName.guardian,
                                                recursively: true) else { return }
        activeGuardian = guardian
        guardianOriginalPosition = guardian.position

        var raised = guardian.position
        raised.y = Constant.presentationY

        let moveUp = SCNAction.move(to: raised, duration: 4)
        moveUp.timingMode = .easeIn

        guardian.runAction(.fadeIn(duration: 1))
        guardian.runAction(moveUp, completionHandler: completion)
    }

    /// Lowers the guardian back to its resting position.
    /// `completion` fires once the guardian is fully hidden.
    func lowerGuardian(completion: @escaping () -> Void) {
        assertMainThread()

        guard let guardian = activeGuardian,
              let original = guardianOriginalPosition else {
            completion()
            return
        }

        let seq = SCNAction.sequence([
            .move(to: original, duration: 4),
            .fadeOut(duration: 0.5)
        ])
        seq.timingMode = .easeOut
        guardian.runAction(seq, completionHandler: completion)
    }

    // MARK: - Hit testing

    /// Returns the name of the first node hit at `location` in `sceneView`, or `nil`.
    func hitNodeName(at location: CGPoint, in sceneView: ARSCNView) -> String? {
        sceneView.hitTest(location).first?.node.name
    }

    // MARK: - Private helpers

    private func assertMainThread(function: StaticString = #function) {
        assert(Thread.isMainThread,
               "ARSceneDirector.\(function) must be called on the main thread.")
    }
}
