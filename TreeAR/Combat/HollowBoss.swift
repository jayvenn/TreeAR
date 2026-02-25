//
//  HollowBoss.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// Procedural SceneKit model for "The Hollow" — a stocky armored stone golem
/// with big expressive eyes and oversized fists.
///
/// Design: chibi-influenced proportions (big head, round body, stubby limbs)
/// contrasted with menacing details (glowing runes, fangs, brow ridge).
enum HollowBoss {

    static let nodeName = "hollow_boss"
    static let height: Float = 2.2
    static let boundingRadius: Float = 0.6

    // MARK: - Colors

    private static let obsidian     = UIColor(red: 0.12, green: 0.10, blue: 0.14, alpha: 1)
    private static let darkStone    = UIColor(red: 0.18, green: 0.15, blue: 0.20, alpha: 1)
    private static let runeColor    = UIColor(red: 1.0,  green: 0.35, blue: 0.10, alpha: 1)
    private static let coreColor    = UIColor(red: 1.0,  green: 0.45, blue: 0.10, alpha: 1)
    private static let eyeColor     = UIColor(red: 1.0,  green: 0.55, blue: 0.0,  alpha: 1)
    private static let fangColor    = UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 1)

    // MARK: - Model Construction

    static func buildModel() -> SCNNode {
        let root = SCNNode()
        root.name = nodeName

        buildBody(on: root)
        buildHead(on: root)
        buildArms(on: root)
        buildLegs(on: root)
        buildCore(on: root)

        return root
    }

    // MARK: - Body Parts

    private static func buildBody(on root: SCNNode) {
        let torso = SCNNode(geometry: SCNSphere(radius: 0.42))
        torso.scale = SCNVector3(1.0, 1.15, 0.85)
        torso.geometry?.firstMaterial = makeArmorMaterial()
        torso.position = SCNVector3(0, 0.9, 0)
        torso.name = "torso"
        root.addChildNode(torso)

        let belly = SCNNode(geometry: SCNSphere(radius: 0.32))
        belly.scale = SCNVector3(1.0, 0.8, 0.9)
        belly.geometry?.firstMaterial = makeStoneMaterial()
        belly.position = SCNVector3(0, 0.55, 0.04)
        root.addChildNode(belly)

        for xOff: Float in [-0.14, 0.14] {
            let rune = SCNNode(geometry: SCNBox(width: 0.04, height: 0.12, length: 0.01, chamferRadius: 0.005))
            rune.geometry?.firstMaterial = makeRuneMaterial()
            rune.position = SCNVector3(xOff, 0.9, 0.38)
            rune.name = "rune"
            root.addChildNode(rune)
        }
    }

    private static func buildHead(on root: SCNNode) {
        let skull = SCNNode(geometry: SCNSphere(radius: 0.30))
        skull.scale = SCNVector3(1.05, 0.95, 1.0)
        skull.geometry?.firstMaterial = makeArmorMaterial()
        skull.position = SCNVector3(0, 1.6, 0.04)
        skull.name = "head"
        root.addChildNode(skull)

        for xOff: Float in [-0.10, 0.10] {
            let socket = SCNNode(geometry: SCNSphere(radius: 0.07))
            socket.geometry?.firstMaterial = makeStoneMaterial()
            socket.position = SCNVector3(xOff, 1.6, 0.26)
            root.addChildNode(socket)

            let eye = SCNNode(geometry: SCNSphere(radius: 0.055))
            eye.geometry?.firstMaterial = makeEyeMaterial()
            eye.position = SCNVector3(xOff, 1.6, 0.28)
            eye.name = "eye"
            root.addChildNode(eye)

            let pupil = SCNNode(geometry: SCNSphere(radius: 0.022))
            pupil.geometry?.firstMaterial = makePupilMaterial()
            pupil.position = SCNVector3(xOff, 1.6, 0.32)
            root.addChildNode(pupil)

            let glow = SCNLight()
            glow.type = .omni
            glow.color = eyeColor
            glow.intensity = 80
            glow.attenuationStartDistance = 0
            glow.attenuationEndDistance = 0.4
            eye.light = glow
        }

        let brow = SCNNode(geometry: SCNBox(width: 0.28, height: 0.055, length: 0.10, chamferRadius: 0.02))
        brow.geometry?.firstMaterial = makeArmorMaterial()
        brow.position = SCNVector3(0, 1.70, 0.20)
        brow.eulerAngles.x = 0.15
        root.addChildNode(brow)

        for xOff: Float in [-0.055, 0.055] {
            let fang = SCNNode(geometry: SCNCone(topRadius: 0.005, bottomRadius: 0.018, height: 0.055))
            fang.geometry?.firstMaterial = makeFangMaterial()
            fang.position = SCNVector3(xOff, 1.45, 0.22)
            root.addChildNode(fang)
        }

        for side: Float in [-1, 1] {
            let horn = SCNNode(geometry: SCNCapsule(capRadius: 0.03, height: 0.12))
            horn.geometry?.firstMaterial = makeStoneMaterial()
            horn.position = SCNVector3(side * 0.22, 1.78, -0.04)
            horn.eulerAngles = SCNVector3(0.2, 0, side * -0.5)
            root.addChildNode(horn)
        }

        for side: Float in [-1, 1] {
            let ear = SCNNode(geometry: SCNSphere(radius: 0.055))
            ear.scale = SCNVector3(0.5, 1.0, 0.8)
            ear.geometry?.firstMaterial = makeStoneMaterial()
            ear.position = SCNVector3(side * 0.30, 1.62, -0.02)
            root.addChildNode(ear)
        }
    }

    private static func buildArms(on root: SCNNode) {
        for side: Float in [-1, 1] {
            let shoulder = SCNNode(geometry: SCNSphere(radius: 0.10))
            shoulder.geometry?.firstMaterial = makeArmorMaterial()
            shoulder.position = SCNVector3(side * 0.48, 1.1, 0)
            root.addChildNode(shoulder)

            let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.075, height: 0.32))
            arm.geometry?.firstMaterial = makeStoneMaterial()
            arm.position = SCNVector3(0, -0.15, 0)
            shoulder.addChildNode(arm)

            let fist = SCNNode(geometry: SCNSphere(radius: 0.12))
            fist.geometry?.firstMaterial = makeArmorMaterial()
            fist.position = SCNVector3(0, -0.38, 0)
            shoulder.addChildNode(fist)

            let runeStrip = SCNNode(geometry: SCNBox(width: 0.025, height: 0.08, length: 0.01, chamferRadius: 0.003))
            runeStrip.geometry?.firstMaterial = makeRuneMaterial()
            runeStrip.position = SCNVector3(side * 0.05, -0.32, 0.09)
            runeStrip.name = "rune"
            shoulder.addChildNode(runeStrip)

            shoulder.name = side < 0 ? "arm_left" : "arm_right"
            shoulder.eulerAngles.z = side * 0.15
        }
    }

    private static func buildLegs(on root: SCNNode) {
        for side: Float in [-1, 1] {
            let hip = SCNNode()
            hip.position = SCNVector3(side * 0.15, 0.30, 0)
            hip.name = side < 0 ? "leg_left" : "leg_right"

            let leg = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.24))
            leg.geometry?.firstMaterial = makeStoneMaterial()
            leg.position = SCNVector3(0, -0.04, 0)
            hip.addChildNode(leg)

            let foot = SCNNode(geometry: SCNSphere(radius: 0.07))
            foot.scale = SCNVector3(1.1, 0.4, 1.4)
            foot.geometry?.firstMaterial = makeArmorMaterial()
            foot.position = SCNVector3(0, -0.22, 0.03)
            hip.addChildNode(foot)

            root.addChildNode(hip)
        }
    }

    private static func buildCore(on root: SCNNode) {
        let core = SCNNode(geometry: SCNSphere(radius: 0.07))
        core.geometry?.firstMaterial = makeCoreMaterial()
        core.position = SCNVector3(0, 0.95, 0.40)
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
        mat.emission.intensity = 0.8
        mat.lightingModel = .constant
        return mat
    }

    private static func makeEyeMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = eyeColor
        mat.emission.contents = eyeColor
        mat.emission.intensity = 1.5
        mat.lightingModel = .constant
        return mat
    }

    private static func makePupilMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
        mat.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)
        mat.emission.intensity = 2.0
        mat.lightingModel = .constant
        return mat
    }

    private static func makeFangMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = fangColor
        mat.roughness.contents = 0.4
        mat.metalness.contents = 0.1
        return mat
    }

    private static func makeCoreMaterial() -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = coreColor
        mat.emission.contents = coreColor
        mat.emission.intensity = 1.2
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
        .customAction(duration: 1.0) { node, elapsed in
            let t = elapsed / 1.0
            if node.name == "eye" {
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(1.5 + t * 1.5)
            }
            if node.name == "rune" {
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(0.8 + t * 1.2)
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
