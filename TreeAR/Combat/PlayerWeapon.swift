//
//  PlayerWeapon.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// First-person runic greatsword attached to the camera node.
///
/// The weapon sits at the bottom-right of the player's view like a classic FPS weapon.
/// On tap it swings forward in an arc; a hit check fires at the apex of the swing.
enum PlayerWeapon {

    static let nodeName = "player_weapon"

    // MARK: - Colors

    private static let bladeDark    = UIColor(red: 0.12, green: 0.10, blue: 0.14, alpha: 1)
    private static let bladeEdge    = UIColor(red: 0.3,  green: 0.7,  blue: 1.0,  alpha: 1)
    private static let handleBrown  = UIColor(red: 0.25, green: 0.15, blue: 0.08, alpha: 1)
    private static let guardMetal   = UIColor(red: 0.3,  green: 0.28, blue: 0.35, alpha: 1)
    private static let runeGlow     = UIColor(red: 0.2,  green: 0.6,  blue: 1.0,  alpha: 1)
    private static let gemColor     = UIColor(red: 0.1,  green: 0.4,  blue: 1.0,  alpha: 1)

    /// Camera-relative rest position (bottom-right of view, angled).
    static let restPosition  = SCNVector3(0.055, -0.10, -0.22)
    static let restEuler     = SCNVector3(-0.15, -0.25, -0.12)

    // MARK: - Build

    static func buildModel() -> SCNNode {
        let root = SCNNode()
        root.name = nodeName

        buildBlade(on: root)
        buildCrossguard(on: root)
        buildHandle(on: root)
        buildPommel(on: root)
        addBladeRunes(on: root)
        addEdgeGlow(on: root)
        addAmbientParticles(on: root)

        root.scale = SCNVector3(0.7, 0.7, 0.7)
        root.renderingOrder = 200
        disableDepthRead(on: root)
        return root
    }

    /// Prevents person-segmentation and world-geometry occlusion from hiding the weapon.
    private static func disableDepthRead(on node: SCNNode) {
        node.geometry?.materials.forEach { $0.readsFromDepthBuffer = false }
        node.childNodes.forEach { disableDepthRead(on: $0) }
    }

    // MARK: - Parts

    private static func buildBlade(on root: SCNNode) {
        let blade = SCNNode(geometry: SCNBox(width: 0.02, height: 0.32, length: 0.06, chamferRadius: 0.003))
        blade.geometry?.firstMaterial = makeBladeCoreMaterial()
        blade.position = SCNVector3(0, 0.22, 0)
        blade.name = "blade"
        root.addChildNode(blade)

        let tip = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.03, height: 0.06))
        tip.geometry?.firstMaterial = makeBladeCoreMaterial()
        tip.position = SCNVector3(0, 0.41, 0)
        root.addChildNode(tip)

        for side: Float in [-1, 1] {
            let edge = SCNNode(geometry: SCNBox(width: 0.004, height: 0.32, length: 0.002, chamferRadius: 0))
            edge.geometry?.firstMaterial = makeEdgeMaterial()
            edge.position = SCNVector3(0, 0.22, side * 0.031)
            edge.name = "blade_edge"
            root.addChildNode(edge)
        }
    }

    private static func buildCrossguard(on root: SCNNode) {
        let guard1 = SCNNode(geometry: SCNBox(width: 0.035, height: 0.015, length: 0.12, chamferRadius: 0.004))
        guard1.geometry?.firstMaterial = makeGuardMaterial()
        guard1.position = SCNVector3(0, 0.055, 0)
        root.addChildNode(guard1)

        for side: Float in [-1, 1] {
            let tip = SCNNode(geometry: SCNSphere(radius: 0.01))
            tip.geometry?.firstMaterial = makeGemMaterial()
            tip.position = SCNVector3(0, 0.055, side * 0.065)
            tip.name = "guard_gem"
            root.addChildNode(tip)
        }
    }

    private static func buildHandle(on root: SCNNode) {
        let grip = SCNNode(geometry: SCNCapsule(capRadius: 0.01, height: 0.09))
        grip.geometry?.firstMaterial = makeHandleMaterial()
        grip.position = SCNVector3(0, 0, 0)
        root.addChildNode(grip)

        for i in 0..<4 {
            let wrap = SCNNode(geometry: SCNTorus(ringRadius: 0.012, pipeRadius: 0.002))
            wrap.geometry?.firstMaterial = makeGuardMaterial()
            wrap.position = SCNVector3(0, Float(i) * 0.02 - 0.03, 0)
            wrap.eulerAngles.x = .pi / 2
            root.addChildNode(wrap)
        }
    }

    private static func buildPommel(on root: SCNNode) {
        let pommel = SCNNode(geometry: SCNSphere(radius: 0.015))
        pommel.geometry?.firstMaterial = makeGuardMaterial()
        pommel.position = SCNVector3(0, -0.055, 0)
        root.addChildNode(pommel)

        let gem = SCNNode(geometry: SCNSphere(radius: 0.008))
        gem.geometry?.firstMaterial = makeGemMaterial()
        gem.position = SCNVector3(0, -0.055, 0)
        gem.name = "pommel_gem"
        root.addChildNode(gem)
    }

    private static func addBladeRunes(on root: SCNNode) {
        let runePositions: [Float] = [0.12, 0.20, 0.28, 0.36]
        for y in runePositions {
            let rune = SCNNode(geometry: SCNBox(width: 0.022, height: 0.015, length: 0.002, chamferRadius: 0.001))
            rune.geometry?.firstMaterial = makeRuneMaterial()
            rune.position = SCNVector3(0, y, 0.031)
            rune.name = "weapon_rune"
            root.addChildNode(rune)
        }
    }

    private static func addEdgeGlow(on root: SCNNode) {
        let glowNode = SCNNode()
        glowNode.position = SCNVector3(0, 0.22, 0)

        let glow = SCNLight()
        glow.type = .omni
        glow.color = bladeEdge
        glow.intensity = 60
        glow.attenuationStartDistance = 0
        glow.attenuationEndDistance = 0.3
        glowNode.light = glow
        root.addChildNode(glowNode)

        let pulse = SCNAction.repeatForever(.sequence([
            .customAction(duration: 1.5) { node, elapsed in
                let t = elapsed / 1.5
                node.light?.intensity = CGFloat(40 + sin(Float(t) * .pi) * 30)
            }
        ]))
        glowNode.runAction(pulse)
    }

    private static func addAmbientParticles(on root: SCNNode) {
        let node = SCNNode()
        node.position = SCNVector3(0, 0.22, 0)

        let particles = SCNParticleSystem()
        particles.birthRate = 8
        particles.particleLifeSpan = 0.8
        particles.particleSize = 0.004
        particles.particleSizeVariation = 0.002
        particles.particleColor = bladeEdge.withAlphaComponent(0.6)
        particles.emitterShape = SCNBox(width: 0.02, height: 0.3, length: 0.06, chamferRadius: 0)
        particles.particleVelocity = 0.02
        particles.spreadingAngle = 90
        particles.blendMode = .additive
        particles.isLightingEnabled = false

        node.addParticleSystem(particles)
        root.addChildNode(node)
    }

    // MARK: - Materials

    private static func makeBladeCoreMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = bladeDark
        m.roughness.contents = 0.4
        m.metalness.contents = 0.7
        m.specular.contents = UIColor(white: 0.5, alpha: 1)
        return m
    }

    private static func makeEdgeMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = bladeEdge
        m.emission.contents = bladeEdge
        m.emission.intensity = 1.2
        m.lightingModel = .constant
        return m
    }

    private static func makeGuardMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = guardMetal
        m.roughness.contents = 0.5
        m.metalness.contents = 0.6
        return m
    }

    private static func makeHandleMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = handleBrown
        m.roughness.contents = 0.9
        m.metalness.contents = 0.05
        return m
    }

    private static func makeRuneMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = runeGlow
        m.emission.contents = runeGlow
        m.emission.intensity = 2.0
        m.lightingModel = .constant
        return m
    }

    private static func makeGemMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = gemColor
        m.emission.contents = gemColor
        m.emission.intensity = 1.5
        m.lightingModel = .constant
        m.transparency = 0.8
        return m
    }

    // MARK: - Animations

    static let idleSwayKey = "weapon_idle_sway"

    /// Gentle bob/sway while the weapon is at rest.
    static func idleSwayAnimation() -> SCNAction {
        let bobUp   = SCNAction.move(by: SCNVector3(0, 0.004, 0), duration: 1.2)
        bobUp.timingMode = .easeInEaseOut
        let bobDown = SCNAction.move(by: SCNVector3(0, -0.004, 0), duration: 1.2)
        bobDown.timingMode = .easeInEaseOut
        let rotLeft  = SCNAction.rotateTo(x: CGFloat(restEuler.x), y: CGFloat(restEuler.y - 0.02), z: CGFloat(restEuler.z), duration: 1.2)
        rotLeft.timingMode = .easeInEaseOut
        let rotRight = SCNAction.rotateTo(x: CGFloat(restEuler.x), y: CGFloat(restEuler.y + 0.02), z: CGFloat(restEuler.z), duration: 1.2)
        rotRight.timingMode = .easeInEaseOut

        return .repeatForever(.sequence([
            .group([bobUp, rotLeft]),
            .group([bobDown, rotRight])
        ]))
    }

    /// Full swing: pull back → slash forward → return to rest.
    /// Three visual variants (0, 1, 2) cycle for variety; same hit logic. `onApex` fires at max extension (hit check time).
    static func swingAnimation(variant: Int = 0, onApex: @escaping () -> Void) -> SCNAction {
        let v = variant % 3
        let (windX, windY, windZ, windD): (CGFloat, CGFloat, CGFloat, TimeInterval)
        let (slashX, slashY, slashZ, slashD): (CGFloat, CGFloat, CGFloat, TimeInterval)
        let recoverD: TimeInterval
        switch v {
        case 0:
            windX = -0.4; windY = 0.4; windZ = 0.3; windD = 0.08
            slashX = 0.1; slashY = -0.8; slashZ = -0.4; slashD = 0.1
            recoverD = 0.25
        case 1:
            windX = -0.35; windY = 0.5; windZ = 0.25; windD = 0.07
            slashX = 0.05; slashY = -0.85; slashZ = -0.35; slashD = 0.11
            recoverD = 0.22
        case 2:
            windX = -0.45; windY = 0.35; windZ = 0.35; windD = 0.09
            slashX = 0.12; slashY = -0.75; slashZ = -0.45; slashD = 0.095
            recoverD = 0.26
        default:
            windX = -0.4; windY = 0.4; windZ = 0.3; windD = 0.08
            slashX = 0.1; slashY = -0.8; slashZ = -0.4; slashD = 0.1
            recoverD = 0.25
        }

        let windUp = SCNAction.group([
            .rotateTo(x: windX, y: windY, z: windZ, duration: windD),
            .move(by: SCNVector3(0.02, 0.03, 0.02), duration: windD)
        ])
        windUp.timingMode = .easeIn

        let slash = SCNAction.group([
            .rotateTo(x: slashX, y: slashY, z: slashZ, duration: slashD),
            .move(by: SCNVector3(-0.06, -0.02, -0.06), duration: slashD)
        ])
        slash.timingMode = .easeOut

        let apex = SCNAction.run { _ in onApex() }

        let recover = SCNAction.group([
            .rotateTo(x: CGFloat(restEuler.x), y: CGFloat(restEuler.y), z: CGFloat(restEuler.z), duration: recoverD),
            .move(to: restPosition, duration: recoverD)
        ])
        recover.timingMode = .easeInEaseOut

        return .sequence([windUp, slash, apex, recover])
    }

    /// Rune flare that plays on the blade during a successful hit.
    static func hitFlareAnimation() -> SCNAction {
        .customAction(duration: 0.2) { node, elapsed in
            let t = elapsed / 0.2
            if node.name == "weapon_rune" || node.name == "blade_edge" || node.name == "guard_gem" || node.name == "pommel_gem" {
                let v = t < 0.5 ? t * 2 : (1 - t) * 2
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(2.0 + v * 4.0)
            }
        }
    }

    /// Returns runes to normal emission intensity.
    static func hitFlareResetAnimation() -> SCNAction {
        .customAction(duration: 0.01) { node, _ in
            if node.name == "weapon_rune" || node.name == "blade_edge" {
                node.geometry?.firstMaterial?.emission.intensity = 2.0
            }
            if node.name == "guard_gem" || node.name == "pommel_gem" {
                node.geometry?.firstMaterial?.emission.intensity = 1.5
            }
        }
    }

    // MARK: - Machine Gun Mode

    private static let machineGunColor = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)

    /// Quick forward jab for rapid-fire machine gun mode.
    static func rapidJabAnimation(onApex: @escaping () -> Void) -> SCNAction {
        let jab = SCNAction.group([
            .rotateTo(x: 0.05, y: CGFloat(restEuler.y), z: CGFloat(restEuler.z) - 0.1, duration: 0.04),
            .move(by: SCNVector3(0, 0.01, -0.04), duration: 0.04)
        ])
        jab.timingMode = .easeOut
        let apex = SCNAction.run { _ in onApex() }
        let retract = SCNAction.group([
            .rotateTo(x: CGFloat(restEuler.x), y: CGFloat(restEuler.y), z: CGFloat(restEuler.z), duration: 0.06),
            .move(to: restPosition, duration: 0.06)
        ])
        retract.timingMode = .easeInEaseOut
        return .sequence([jab, apex, retract])
    }

    /// Tints runes and edges purple for machine gun mode.
    static func activateMachineGunVisual(on weaponNode: SCNNode) {
        for child in weaponNode.childNodes {
            if child.name == "weapon_rune" || child.name == "blade_edge" {
                child.geometry?.firstMaterial?.diffuse.contents = machineGunColor
                child.geometry?.firstMaterial?.emission.contents = machineGunColor
                child.geometry?.firstMaterial?.emission.intensity = 3.0
            }
            if child.name == "guard_gem" || child.name == "pommel_gem" {
                child.geometry?.firstMaterial?.diffuse.contents = machineGunColor
                child.geometry?.firstMaterial?.emission.contents = machineGunColor
            }
        }
    }

    /// Reverts runes and edges to normal blue.
    static func deactivateMachineGunVisual(on weaponNode: SCNNode) {
        for child in weaponNode.childNodes {
            if child.name == "weapon_rune" || child.name == "blade_edge" {
                child.geometry?.firstMaterial?.diffuse.contents = bladeEdge
                child.geometry?.firstMaterial?.emission.contents = bladeEdge
                child.geometry?.firstMaterial?.emission.intensity = child.name == "blade_edge" ? 1.2 : 2.0
            }
            if child.name == "guard_gem" || child.name == "pommel_gem" {
                child.geometry?.firstMaterial?.diffuse.contents = gemColor
                child.geometry?.firstMaterial?.emission.contents = gemColor
            }
        }
    }

    static func spawnRapidTrail(on weaponNode: SCNNode) {
        let n = SCNNode()
        n.position = SCNVector3(0, 0.22, 0)
        let p = SCNParticleSystem()
        p.birthRate = 60
        p.particleLifeSpan = 0.1
        p.particleSize = 0.006
        p.particleColor = machineGunColor
        p.emitterShape = SCNBox(width: 0.02, height: 0.2, length: 0.04, chamferRadius: 0)
        p.particleVelocity = 0.3
        p.spreadingAngle = 45
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.loops = false
        p.emissionDuration = 0.06
        n.addParticleSystem(p)
        weaponNode.addChildNode(n)
        n.runAction(.sequence([.wait(duration: 0.3), .removeFromParentNode()]))
    }

    /// Spawn slash trail particles at the blade position.
    static func spawnSlashTrail(on weaponNode: SCNNode) {
        let trailNode = SCNNode()
        trailNode.position = SCNVector3(0, 0.22, 0)

        let trail = SCNParticleSystem()
        trail.birthRate = 120
        trail.particleLifeSpan = 0.15
        trail.particleSize = 0.008
        trail.particleSizeVariation = 0.004
        trail.particleColor = bladeEdge
        trail.particleColorVariation = SCNVector4(0.05, 0.1, 0, 0.2)
        trail.emitterShape = SCNBox(width: 0.02, height: 0.25, length: 0.06, chamferRadius: 0)
        trail.particleVelocity = 0.5
        trail.spreadingAngle = 60
        trail.blendMode = .additive
        trail.isLightingEnabled = false
        trail.loops = false
        trail.emissionDuration = 0.12

        trailNode.addParticleSystem(trail)
        weaponNode.addChildNode(trailNode)
        trailNode.runAction(.sequence([.wait(duration: 0.4), .removeFromParentNode()]))
    }
}
