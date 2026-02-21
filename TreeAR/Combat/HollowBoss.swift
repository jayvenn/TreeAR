//
//  HollowBoss.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// Procedural SceneKit model for the V1 boss "The Hollow" — a stone golem.
///
/// Built from primitive geometry so no external .scn file is required.
/// Replace with a real model by swapping `buildModel()` for a scene file load.
enum HollowBoss {

    /// Root node name used for hit-testing identification.
    static let nodeName = "hollow_boss"
    static let height: Float = 2.0
    static let boundingRadius: Float = 0.6

    // MARK: - Model Construction

    static func buildModel() -> SCNNode {
        let root = SCNNode()
        root.name = nodeName

        let stoneMaterial = makeStoneMaterial()
        let glowMaterial = makeGlowMaterial()

        // Torso
        let torso = SCNNode(geometry: SCNBox(width: 0.7, height: 0.9, length: 0.5, chamferRadius: 0.08))
        torso.geometry?.firstMaterial = stoneMaterial
        torso.position = SCNVector3(0, 1.0, 0)
        root.addChildNode(torso)

        // Head
        let head = SCNNode(geometry: SCNSphere(radius: 0.25))
        head.geometry?.firstMaterial = stoneMaterial
        head.position = SCNVector3(0, 1.7, 0)
        root.addChildNode(head)

        // Eyes (glowing)
        for xOffset: Float in [-0.08, 0.08] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.04))
            eye.geometry?.firstMaterial = glowMaterial
            eye.position = SCNVector3(xOffset, 1.75, 0.22)
            eye.name = "eye"
            root.addChildNode(eye)
        }

        // Arms
        for side: Float in [-1, 1] {
            let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.1, height: 0.8))
            arm.geometry?.firstMaterial = stoneMaterial
            arm.position = SCNVector3(side * 0.5, 1.05, 0)
            arm.eulerAngles.z = side * 0.15
            arm.name = side < 0 ? "arm_left" : "arm_right"
            root.addChildNode(arm)
        }

        // Legs
        for side: Float in [-1, 1] {
            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.12, height: 0.7))
            leg.geometry?.firstMaterial = stoneMaterial
            leg.position = SCNVector3(side * 0.2, 0.35, 0)
            leg.name = side < 0 ? "leg_left" : "leg_right"
            root.addChildNode(leg)
        }

        return root
    }

    // MARK: - Materials

    private static func makeStoneMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.35, green: 0.33, blue: 0.30, alpha: 1)
        mat.roughness.contents = 0.9
        mat.metalness.contents = 0.1
        return mat
    }

    private static func makeGlowMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemRed
        mat.emission.contents = UIColor.systemRed
        mat.lightingModel = .constant
        return mat
    }

    // MARK: - Animations

    /// Boss rises from below the ground plane.
    static func spawnAnimation(duration: TimeInterval = 2.5) -> SCNAction {
        let rise = SCNAction.move(by: SCNVector3(0, height, 0), duration: duration)
        rise.timingMode = .easeOut
        let fade = SCNAction.fadeIn(duration: duration * 0.6)
        return .group([rise, fade])
    }

    /// Both arms raise overhead (ground slam telegraph).
    static func groundSlamTelegraphAnimation(duration: TimeInterval) -> (left: SCNAction, right: SCNAction) {
        let raiseLeft = SCNAction.rotateTo(x: 0, y: 0, z: -.pi / 1.2, duration: duration)
        raiseLeft.timingMode = .easeIn
        let raiseRight = SCNAction.rotateTo(x: 0, y: 0, z: .pi / 1.2, duration: duration)
        raiseRight.timingMode = .easeIn
        return (raiseLeft, raiseRight)
    }

    /// Arms slam down.
    static func groundSlamExecuteAnimation() -> (left: SCNAction, right: SCNAction) {
        let slamLeft = SCNAction.rotateTo(x: 0, y: 0, z: 0.15, duration: 0.15)
        slamLeft.timingMode = .easeIn
        let slamRight = SCNAction.rotateTo(x: 0, y: 0, z: -0.15, duration: 0.15)
        slamRight.timingMode = .easeIn
        return (slamLeft, slamRight)
    }

    /// One arm pulls back then sweeps across.
    static func sweepTelegraphAnimation(duration: TimeInterval) -> SCNAction {
        let pullBack = SCNAction.rotateTo(x: 0, y: .pi / 2, z: -.pi / 3, duration: duration)
        pullBack.timingMode = .easeIn
        return pullBack
    }

    static func sweepExecuteAnimation() -> SCNAction {
        let swing = SCNAction.rotateTo(x: 0, y: -.pi / 2, z: -.pi / 3, duration: 0.3)
        swing.timingMode = .easeOut
        return swing
    }

    /// One leg lifts (stomp telegraph).
    static func stompTelegraphAnimation(duration: TimeInterval) -> SCNAction {
        let lift = SCNAction.move(by: SCNVector3(0, 0.3, 0), duration: duration)
        lift.timingMode = .easeIn
        return lift
    }

    static func stompExecuteAnimation() -> SCNAction {
        let slam = SCNAction.move(by: SCNVector3(0, -0.3, 0), duration: 0.12)
        slam.timingMode = .easeIn
        return slam
    }

    /// Return arms/legs to neutral.
    static func resetPoseAnimation(duration: TimeInterval = 0.5) -> SCNAction {
        .rotateTo(x: 0, y: 0, z: 0, duration: duration)
    }

    /// Boss flashes red (hit feedback).
    static func hitFlashAnimation() -> SCNAction {
        let tint = SCNAction.customAction(duration: 0.2) { node, elapsed in
            let fraction = elapsed / 0.2
            let alpha = fraction < 0.5 ? fraction * 2 : (1 - fraction) * 2
            node.geometry?.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(CGFloat(alpha) * 0.6)
        }
        let clear = SCNAction.customAction(duration: 0.01) { node, _ in
            node.geometry?.firstMaterial?.emission.contents = UIColor.black
        }
        return .sequence([tint, clear])
    }

    /// Phase-transition enrage: eyes glow brighter, body tints slightly red.
    static func enrageAnimation() -> SCNAction {
        .customAction(duration: 1.0) { node, elapsed in
            let frac = elapsed / 1.0
            if node.name == "eye" {
                let intensity = 1.0 + frac * 2.0
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(intensity)
            }
        }
    }

    /// Death animation: stagger, crack, dissolve.
    static func deathAnimation(duration: TimeInterval = 3.0) -> SCNAction {
        let stagger = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: 0.1, duration: 0.3),
            .rotateBy(x: 0, y: 0, z: -0.2, duration: 0.3),
            .rotateBy(x: 0, y: 0, z: 0.1, duration: 0.3)
        ])
        let sink = SCNAction.move(by: SCNVector3(0, -0.5, 0), duration: duration * 0.6)
        sink.timingMode = .easeIn
        let fade = SCNAction.fadeOut(duration: duration * 0.4)
        return .sequence([stagger, .group([sink, fade])])
    }
}
