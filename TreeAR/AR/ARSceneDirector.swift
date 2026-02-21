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
/// Completion handlers are **always** delivered on the main thread — guaranteed by
/// `mainThreadCompletion(_:)` which wraps every `SCNAction` callback.
///
/// **Why this matters:** `SCNAction.runAction(_:completionHandler:)` fires its closure
/// on SceneKit's internal renderer thread, not the main thread. Every public method
/// that accepts a completion block must wrap it before passing it to `SCNAction`.
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

    // MARK: - Boss state

    private(set) var bossNode: SCNNode?
    let telegraphRenderer = BossTelegraphRenderer()

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
        grassNode.runAction(.grassGrowSequenceAction(grassNode),
                            completionHandler: mainThreadCompletion(completion))
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
        let wrappedCompletion = mainThreadCompletion { completion(mainNode) }
        coverNode.runAction(coverSeq, completionHandler: wrappedCompletion)
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
        guardian.runAction(moveUp, completionHandler: mainThreadCompletion(completion))
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
        guardian.runAction(seq, completionHandler: mainThreadCompletion(completion))
    }

    // MARK: - Phase 5: Boss

    /// Builds and spawns the boss at the tracker anchor.
    /// The boss starts below the ground plane and rises dramatically.
    func spawnBoss(completion: @escaping () -> Void) {
        assertMainThread()
        guard let tracker = trackerNode else { return }

        dismissPreCombatNodes()

        let boss = HollowBoss.buildModel()
        boss.position = SCNVector3(0, -HollowBoss.height, 0)
        boss.opacity = 0
        tracker.addChildNode(boss)
        self.bossNode = boss

        telegraphRenderer.configure(parentNode: boss)

        boss.runAction(HollowBoss.spawnAnimation(),
                       completionHandler: mainThreadCompletion(completion))
    }

    /// Rotates the boss to face the camera each frame.
    func updateBossFacing(cameraTransform: simd_float4x4) {
        guard let boss = bossNode else { return }
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let bossWorldPos = boss.worldPosition
        let angle = atan2(camX - bossWorldPos.x, camZ - bossWorldPos.z)
        boss.eulerAngles.y = angle
    }

    /// Returns horizontal distance from camera to boss center.
    func distanceToBoss(cameraTransform: simd_float4x4) -> Float {
        guard let boss = bossNode else { return .greatestFiniteMagnitude }
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let bossPos = boss.worldPosition
        let dx = camX - bossPos.x
        let dz = camZ - bossPos.z
        return sqrt(dx * dx + dz * dz)
    }

    /// Whether the camera is behind the boss (for sweep dodge detection).
    func isCameraBehindBoss(cameraTransform: simd_float4x4) -> Bool {
        guard let boss = bossNode else { return false }
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let bossPos = boss.worldPosition
        let bossForward = SCNVector3(-sin(boss.eulerAngles.y), 0, -cos(boss.eulerAngles.y))
        let toCamera = SCNVector3(camX - bossPos.x, 0, camZ - bossPos.z)
        let dot = bossForward.x * toCamera.x + bossForward.z * toCamera.z
        return dot < 0
    }

    // MARK: - Boss Attack Animations

    func playTelegraphAnimation(for attack: BossAttack) {
        guard let boss = bossNode else { return }
        telegraphRenderer.showTelegraph(for: attack, duration: attack.telegraphDuration)

        switch attack {
        case .groundSlam:
            let anims = HollowBoss.groundSlamTelegraphAnimation(duration: attack.telegraphDuration)
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(anims.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(anims.right)

        case .sweep:
            let anim = HollowBoss.sweepTelegraphAnimation(duration: attack.telegraphDuration)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(anim)

        case .stompWave:
            let anim = HollowBoss.stompTelegraphAnimation(duration: attack.telegraphDuration)
            boss.childNode(withName: "leg_left", recursively: true)?.runAction(anim)

        case .enragedCombo:
            let anims = HollowBoss.groundSlamTelegraphAnimation(duration: attack.telegraphDuration * 0.7)
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(anims.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(anims.right)
        }
    }

    func playExecuteAnimation(for attack: BossAttack) {
        guard let boss = bossNode else { return }
        telegraphRenderer.flashAndRemoveTelegraphs()

        switch attack {
        case .groundSlam:
            let anims = HollowBoss.groundSlamExecuteAnimation()
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(anims.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(anims.right)

        case .sweep:
            let anim = HollowBoss.sweepExecuteAnimation()
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(anim)

        case .stompWave:
            let anim = HollowBoss.stompExecuteAnimation()
            boss.childNode(withName: "leg_left", recursively: true)?.runAction(anim)

        case .enragedCombo:
            let slamAnims = HollowBoss.groundSlamExecuteAnimation()
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(slamAnims.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(slamAnims.right)
        }
    }

    func playRecoveryAnimation(for attack: BossAttack) {
        guard let boss = bossNode else { return }
        let reset = HollowBoss.resetPoseAnimation(duration: attack.recoveryDuration * 0.5)

        switch attack {
        case .groundSlam, .enragedCombo:
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(reset)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(reset)
        case .sweep:
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(reset)
        case .stompWave:
            boss.childNode(withName: "leg_left", recursively: true)?.runAction(reset)
        }
    }

    func playBossHitFlash() {
        guard let boss = bossNode else { return }
        for child in boss.childNodes where child.name != "eye" {
            child.runAction(HollowBoss.hitFlashAnimation())
        }
    }

    func playEnrageEffect(phase: BossPhase) {
        guard let boss = bossNode else { return }
        for child in boss.childNodes {
            child.runAction(HollowBoss.enrageAnimation())
        }

        if phase == .phase3 {
            let redLight = SCNLight()
            redLight.type = .omni
            redLight.color = UIColor.systemRed
            redLight.intensity = 500
            let lightNode = SCNNode()
            lightNode.light = redLight
            lightNode.position = SCNVector3(0, 1.5, 0)
            boss.addChildNode(lightNode)
        }
    }

    func playBossDeathAnimation(completion: @escaping () -> Void) {
        guard let boss = bossNode else {
            completion()
            return
        }
        telegraphRenderer.removeAllTelegraphs()
        boss.runAction(HollowBoss.deathAnimation(),
                       completionHandler: mainThreadCompletion(completion))
    }

    func removeBoss() {
        bossNode?.removeFromParentNode()
        bossNode = nil
    }

    // MARK: - Hit testing

    /// Returns the name of the first node hit at `location` in `sceneView`, or `nil`.
    func hitNodeName(at location: CGPoint, in sceneView: ARSCNView) -> String? {
        sceneView.hitTest(location).first?.node.name
    }

    // MARK: - Private helpers

    /// Wraps a completion closure to guarantee it executes on the main thread.
    ///
    /// `SCNAction.runAction(_:completionHandler:)` fires its closure on SceneKit's
    /// internal renderer thread. This wrapper ensures every public completion we
    /// hand back to callers honours our documented main-thread contract.
    private func mainThreadCompletion(_ block: @escaping () -> Void) -> () -> Void {
        return {
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        }
    }

    private func dismissPreCombatNodes() {
        magicBoxNode.runAction(.sequence([.fadeOut(duration: 0.8), .removeFromParentNode()]))
        lightsNode.runAction(.sequence([.fadeOut(duration: 0.8), .removeFromParentNode()]))
    }

    private func assertMainThread(function: StaticString = #function) {
        assert(Thread.isMainThread,
               "ARSceneDirector.\(function) must be called on the main thread.")
    }
}
