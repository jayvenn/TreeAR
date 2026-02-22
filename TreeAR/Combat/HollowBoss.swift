//
//  HollowBoss.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// Procedural SceneKit model for "The Hollow" — a towering armored stone demon.
///
/// Built entirely from SceneKit primitives with layered geometry, emission materials
/// for glowing runes, and particle systems for ambient dark energy.
enum HollowBoss {

    static let nodeName = "hollow_boss"
    static let height: Float = 2.2
    static let boundingRadius: Float = 0.6

    // MARK: - Colors

    private static let obsidian     = UIColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1)
    private static let darkStone    = UIColor(red: 0.15, green: 0.13, blue: 0.16, alpha: 1)
    private static let runeColor    = UIColor(red: 1.0,  green: 0.25, blue: 0.08, alpha: 1)
    private static let coreColor    = UIColor(red: 1.0,  green: 0.35, blue: 0.05, alpha: 1)
    private static let eyeColor     = UIColor(red: 1.0,  green: 0.15, blue: 0.0,  alpha: 1)

    // MARK: - Model Construction

    static func buildModel() -> SCNNode {
        let root = SCNNode()
        root.name = nodeName

        buildTorso(on: root)
        buildHead(on: root)
        buildArms(on: root)
        buildLegs(on: root)
        buildCore(on: root)
        buildShoulderArmor(on: root)

        return root
    }

    // MARK: - Body Parts

    private static func buildTorso(on root: SCNNode) {
        let torso = SCNNode(geometry: SCNBox(width: 0.8, height: 1.0, length: 0.55, chamferRadius: 0.05))
        torso.geometry?.firstMaterial = makeArmorMaterial()
        torso.position = SCNVector3(0, 1.1, 0)
        torso.name = "torso"
        root.addChildNode(torso)

        let waist = SCNNode(geometry: SCNBox(width: 0.6, height: 0.25, length: 0.45, chamferRadius: 0.04))
        waist.geometry?.firstMaterial = makeStoneMaterial()
        waist.position = SCNVector3(0, 0.55, 0)
        root.addChildNode(waist)

        for xOff: Float in [-0.25, 0.0, 0.25] {
            let rune = SCNNode(geometry: SCNBox(width: 0.06, height: 0.18, length: 0.01, chamferRadius: 0.01))
            rune.geometry?.firstMaterial = makeRuneMaterial()
            rune.position = SCNVector3(xOff, 1.15, 0.28)
            rune.name = "rune"
            root.addChildNode(rune)
        }
    }

    private static func buildHead(on root: SCNNode) {
        let skull = SCNNode(geometry: SCNBox(width: 0.3, height: 0.32, length: 0.28, chamferRadius: 0.06))
        skull.geometry?.firstMaterial = makeArmorMaterial()
        skull.position = SCNVector3(0, 1.82, 0)
        skull.name = "head"
        root.addChildNode(skull)

        let helmet = SCNNode(geometry: SCNBox(width: 0.34, height: 0.12, length: 0.32, chamferRadius: 0.03))
        helmet.geometry?.firstMaterial = makeArmorMaterial()
        helmet.position = SCNVector3(0, 1.95, 0)
        root.addChildNode(helmet)

        for xOff: Float in [-0.07, 0.07] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.035))
            eye.geometry?.firstMaterial = makeEyeMaterial()
            eye.position = SCNVector3(xOff, 1.85, 0.15)
            eye.name = "eye"
            root.addChildNode(eye)

            let glow = SCNLight()
            glow.type = .omni
            glow.color = eyeColor
            glow.intensity = 80
            glow.attenuationStartDistance = 0
            glow.attenuationEndDistance = 0.3
            eye.light = glow
        }

        let jaw = SCNNode(geometry: SCNBox(width: 0.22, height: 0.08, length: 0.18, chamferRadius: 0.02))
        jaw.geometry?.firstMaterial = makeStoneMaterial()
        jaw.position = SCNVector3(0, 1.7, 0.04)
        root.addChildNode(jaw)

        for side: Float in [-1, 1] {
            let horn = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.2))
            horn.geometry?.firstMaterial = makeArmorMaterial()
            horn.position = SCNVector3(side * 0.16, 2.0, -0.05)
            horn.eulerAngles = SCNVector3(0.3, 0, side * -0.4)
            root.addChildNode(horn)
        }
    }

    private static func buildArms(on root: SCNNode) {
        for side: Float in [-1, 1] {
            let shoulder = SCNNode(geometry: SCNSphere(radius: 0.12))
            shoulder.geometry?.firstMaterial = makeArmorMaterial()
            shoulder.position = SCNVector3(side * 0.52, 1.45, 0)
            root.addChildNode(shoulder)

            let upperArm = SCNNode(geometry: SCNCapsule(capRadius: 0.09, height: 0.5))
            upperArm.geometry?.firstMaterial = makeStoneMaterial()
            upperArm.position = SCNVector3(0, -0.2, 0)
            shoulder.addChildNode(upperArm)

            let forearm = SCNNode(geometry: SCNCapsule(capRadius: 0.08, height: 0.45))
            forearm.geometry?.firstMaterial = makeArmorMaterial()
            forearm.position = SCNVector3(0, -0.45, 0)
            shoulder.addChildNode(forearm)

            let fist = SCNNode(geometry: SCNSphere(radius: 0.1))
            fist.geometry?.firstMaterial = makeStoneMaterial()
            fist.position = SCNVector3(0, -0.7, 0)
            shoulder.addChildNode(fist)

            let runeStrip = SCNNode(geometry: SCNBox(width: 0.03, height: 0.3, length: 0.01, chamferRadius: 0.005))
            runeStrip.geometry?.firstMaterial = makeRuneMaterial()
            runeStrip.position = SCNVector3(side * 0.08, -0.3, 0.08)
            shoulder.addChildNode(runeStrip)

            shoulder.name = side < 0 ? "arm_left" : "arm_right"
            shoulder.eulerAngles.z = side * 0.12
        }
    }

    private static func buildLegs(on root: SCNNode) {
        for side: Float in [-1, 1] {
            let hip = SCNNode()
            hip.position = SCNVector3(side * 0.2, 0.4, 0)
            hip.name = side < 0 ? "leg_left" : "leg_right"

            let thigh = SCNNode(geometry: SCNCapsule(capRadius: 0.11, height: 0.45))
            thigh.geometry?.firstMaterial = makeStoneMaterial()
            thigh.position = SCNVector3(0, -0.05, 0)
            hip.addChildNode(thigh)

            let shin = SCNNode(geometry: SCNCapsule(capRadius: 0.1, height: 0.4))
            shin.geometry?.firstMaterial = makeArmorMaterial()
            shin.position = SCNVector3(0, -0.35, 0)
            hip.addChildNode(shin)

            let foot = SCNNode(geometry: SCNBox(width: 0.16, height: 0.06, length: 0.22, chamferRadius: 0.02))
            foot.geometry?.firstMaterial = makeArmorMaterial()
            foot.position = SCNVector3(0, -0.58, 0.04)
            hip.addChildNode(foot)

            root.addChildNode(hip)
        }
    }

    private static func buildCore(on root: SCNNode) {
        let core = SCNNode(geometry: SCNSphere(radius: 0.1))
        core.geometry?.firstMaterial = makeCoreMaterial()
        core.position = SCNVector3(0, 1.15, 0.29)
        core.name = "core"
        root.addChildNode(core)

        let coreGlow = SCNLight()
        coreGlow.type = .omni
        coreGlow.color = coreColor
        coreGlow.intensity = 150
        coreGlow.attenuationStartDistance = 0
        coreGlow.attenuationEndDistance = 0.6
        core.light = coreGlow

        let pulse = SCNAction.repeatForever(.customAction(duration: 2.0) { node, elapsed in
            let t = elapsed / 2.0
            node.geometry?.firstMaterial?.emission.intensity = CGFloat(1.5 + sin(Float(t) * .pi) * 0.5)
        })
        core.runAction(pulse)
    }

    private static func buildShoulderArmor(on root: SCNNode) {
        for side: Float in [-1, 1] {
            let plate = SCNNode(geometry: SCNBox(width: 0.22, height: 0.15, length: 0.2, chamferRadius: 0.03))
            plate.geometry?.firstMaterial = makeArmorMaterial()
            plate.position = SCNVector3(side * 0.52, 1.55, 0)
            plate.eulerAngles.z = side * -0.3
            root.addChildNode(plate)

            let spike = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.035, height: 0.18))
            spike.geometry?.firstMaterial = makeArmorMaterial()
            spike.position = SCNVector3(side * 0.58, 1.62, 0)
            spike.eulerAngles.z = side * -0.8
            root.addChildNode(spike)
        }
    }

    // MARK: - Materials

    private static func makeStoneMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = darkStone
        mat.roughness.contents = 0.85
        mat.metalness.contents = 0.15
        mat.normal.intensity = 0.8
        return mat
    }

    private static func makeArmorMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = obsidian
        mat.roughness.contents = 0.6
        mat.metalness.contents = 0.4
        mat.specular.contents = UIColor(white: 0.3, alpha: 1)
        return mat
    }

    private static func makeRuneMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = runeColor
        mat.emission.contents = runeColor
        mat.emission.intensity = 1.5
        mat.lightingModel = .constant
        return mat
    }

    private static func makeEyeMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = eyeColor
        mat.emission.contents = eyeColor
        mat.emission.intensity = 2.5
        mat.lightingModel = .constant
        return mat
    }

    private static func makeCoreMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = coreColor
        mat.emission.contents = coreColor
        mat.emission.intensity = 2.0
        mat.lightingModel = .constant
        mat.transparency = 0.85
        return mat
    }

    // MARK: - Spawn

    static func spawnAnimation(duration: TimeInterval = 3.5) -> SCNAction {
        let rise = SCNAction.move(by: SCNVector3(0, height, 0), duration: duration)
        rise.timingMode = .easeOut
        let fadeIn = SCNAction.fadeIn(duration: duration * 0.4)
        let preScale = SCNAction.scale(to: 0.6, duration: 0)
        let scaleUp = SCNAction.scale(to: 1.0, duration: duration * 0.7)
        scaleUp.timingMode = .easeOut
        return .group([rise, fadeIn, .sequence([preScale, scaleUp])])
    }

    // MARK: - Attack Animations

    static func groundSlamTelegraphAnimation(duration: TimeInterval) -> (left: SCNAction, right: SCNAction) {
        let left = SCNAction.rotateTo(x: 0, y: 0, z: -.pi / 1.2, duration: duration)
        left.timingMode = .easeIn
        let right = SCNAction.rotateTo(x: 0, y: 0, z: .pi / 1.2, duration: duration)
        right.timingMode = .easeIn
        return (left, right)
    }

    static func groundSlamExecuteAnimation() -> (left: SCNAction, right: SCNAction) {
        let left = SCNAction.rotateTo(x: 0, y: 0, z: 0.15, duration: 0.12)
        left.timingMode = .easeIn
        let right = SCNAction.rotateTo(x: 0, y: 0, z: -0.15, duration: 0.12)
        right.timingMode = .easeIn
        return (left, right)
    }

    static func sweepTelegraphAnimation(duration: TimeInterval) -> SCNAction {
        let pull = SCNAction.rotateTo(x: 0, y: .pi / 2, z: -.pi / 3, duration: duration)
        pull.timingMode = .easeIn
        return pull
    }

    static func sweepExecuteAnimation() -> SCNAction {
        let swing = SCNAction.rotateTo(x: 0, y: -.pi / 2, z: -.pi / 3, duration: 0.25)
        swing.timingMode = .easeOut
        return swing
    }

    static func stompTelegraphAnimation(duration: TimeInterval) -> SCNAction {
        let lift = SCNAction.move(by: SCNVector3(0, 0.35, 0), duration: duration)
        lift.timingMode = .easeIn
        return lift
    }

    static func stompExecuteAnimation() -> SCNAction {
        let slam = SCNAction.move(by: SCNVector3(0, -0.35, 0), duration: 0.1)
        slam.timingMode = .easeIn
        return slam
    }

    static func resetPoseAnimation(duration: TimeInterval = 0.5) -> SCNAction {
        .rotateTo(x: 0, y: 0, z: 0, duration: duration)
    }

    // MARK: - Hit Feedback

    static func hitFlashAnimation() -> SCNAction {
        let flash = SCNAction.customAction(duration: 0.15) { node, elapsed in
            let t = elapsed / 0.15
            let v = t < 0.5 ? t * 2 : (1 - t) * 2
            node.geometry?.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(CGFloat(v) * 0.8)
        }
        let clear = SCNAction.customAction(duration: 0.01) { node, _ in
            if node.name == "rune" || node.name == "eye" || node.name == "core" { return }
            node.geometry?.firstMaterial?.emission.contents = UIColor.black
        }
        return .sequence([flash, clear])
    }

    static func hitStaggerAnimation() -> SCNAction {
        let back = SCNAction.move(by: SCNVector3(0, 0, -0.03), duration: 0.06)
        let fwd  = SCNAction.move(by: SCNVector3(0, 0,  0.03), duration: 0.12)
        fwd.timingMode = .easeOut
        return .sequence([back, fwd])
    }

    // MARK: - Phase Transitions

    static func enrageAnimation() -> SCNAction {
        .customAction(duration: 1.5) { node, elapsed in
            let t = elapsed / 1.5
            if node.name == "eye" {
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(2.5 + t * 3.0)
            }
            if node.name == "rune" {
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(1.5 + t * 2.0)
            }
        }
    }

    // MARK: - Death

    static func deathAnimation(duration: TimeInterval = 4.0) -> SCNAction {
        let stagger = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: 0.08, duration: 0.2),
            .rotateBy(x: 0.05, y: 0, z: -0.16, duration: 0.3),
            .rotateBy(x: -0.05, y: 0, z: 0.08, duration: 0.2),
            .wait(duration: 0.3)
        ])
        let runeFlare = SCNAction.customAction(duration: 1.0) { node, elapsed in
            let t = elapsed / 1.0
            if node.name == "rune" || node.name == "core" || node.name == "eye" {
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(3.0 + t * 5.0)
            }
        }
        let collapse = SCNAction.group([
            .move(by: SCNVector3(0, -0.8, 0), duration: duration * 0.5),
            .fadeOut(duration: duration * 0.5),
            .scale(to: 0.7, duration: duration * 0.5)
        ])
        return .sequence([stagger, runeFlare, collapse])
    }
}
