//
//  LootDrop.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

// MARK: - Loot Type

enum LootType: CaseIterable {
    case healthPack
    case wizardMachineGun
}

extension LootType {

    var pickupRange: Float { 0.8 }

    /// How long the loot sits on the ground before despawning.
    var despawnTime: TimeInterval { 14.0 }

    var nodeName: String {
        switch self {
        case .healthPack:       return "loot_health"
        case .wizardMachineGun: return "loot_machinegun"
        }
    }
}

// MARK: - Loot Node Builder

enum LootNodeBuilder {

    private static let healthGreen = UIColor(red: 0.1, green: 0.9, blue: 0.3, alpha: 1)
    private static let gunPurple   = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)

    static func build(type: LootType) -> SCNNode {
        let root = SCNNode()
        root.name = type.nodeName

        switch type {
        case .healthPack:       buildHealthPack(on: root)
        case .wizardMachineGun: buildMachineGun(on: root)
        }

        addLightBeam(on: root, color: type == .healthPack ? healthGreen : gunPurple)
        addBaseGlow(on: root, color: type == .healthPack ? healthGreen : gunPurple)
        addFloatAndSpin(on: root)

        return root
    }

    // MARK: - Health Pack

    private static func buildHealthPack(on root: SCNNode) {
        let body = SCNNode(geometry: SCNBox(width: 0.12, height: 0.12, length: 0.12, chamferRadius: 0.02))
        body.geometry?.firstMaterial = makeGlowMaterial(healthGreen.withAlphaComponent(0.85))
        body.position = SCNVector3(0, 0.15, 0)
        body.name = "loot_health"
        root.addChildNode(body)

        let crossV = SCNNode(geometry: SCNBox(width: 0.025, height: 0.08, length: 0.005, chamferRadius: 0))
        crossV.geometry?.firstMaterial = makeEmissiveMaterial(.white)
        crossV.position = SCNVector3(0, 0, 0.063)
        body.addChildNode(crossV)

        let crossH = SCNNode(geometry: SCNBox(width: 0.08, height: 0.025, length: 0.005, chamferRadius: 0))
        crossH.geometry?.firstMaterial = makeEmissiveMaterial(.white)
        crossH.position = SCNVector3(0, 0, 0.063)
        body.addChildNode(crossH)
    }

    // MARK: - Wizard Machine Gun

    private static func buildMachineGun(on root: SCNNode) {
        let orb = SCNNode(geometry: SCNSphere(radius: 0.07))
        orb.geometry?.firstMaterial = makeGlowMaterial(gunPurple)
        orb.position = SCNVector3(0, 0.15, 0)
        orb.name = "loot_machinegun"
        root.addChildNode(orb)

        let innerOrb = SCNNode(geometry: SCNSphere(radius: 0.04))
        innerOrb.geometry?.firstMaterial = makeEmissiveMaterial(UIColor(red: 0.8, green: 0.5, blue: 1.0, alpha: 1))
        orb.addChildNode(innerOrb)

        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.09, pipeRadius: 0.008))
        ring.geometry?.firstMaterial = makeEmissiveMaterial(gunPurple)
        ring.position = SCNVector3(0, 0.15, 0)
        ring.name = "loot_machinegun"
        root.addChildNode(ring)

        let ringAnim = SCNAction.repeatForever(.rotateBy(x: .pi * 2, y: 0, z: 0, duration: 2.0))
        ring.runAction(ringAnim)

        let ring2 = SCNNode(geometry: SCNTorus(ringRadius: 0.09, pipeRadius: 0.006))
        ring2.geometry?.firstMaterial = makeEmissiveMaterial(gunPurple.withAlphaComponent(0.6))
        ring2.position = SCNVector3(0, 0.15, 0)
        ring2.eulerAngles.z = .pi / 2
        ring2.name = "loot_machinegun"
        root.addChildNode(ring2)
        ring2.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3.0)))

        let particles = SCNParticleSystem()
        particles.birthRate = 12
        particles.particleLifeSpan = 0.6
        particles.particleSize = 0.008
        particles.particleColor = gunPurple
        particles.emitterShape = SCNSphere(radius: 0.08)
        particles.particleVelocity = 0.05
        particles.spreadingAngle = 180
        particles.blendMode = .additive
        particles.isLightingEnabled = false
        orb.addParticleSystem(particles)
    }

    // MARK: - Shared Effects

    private static func addLightBeam(on root: SCNNode, color: UIColor) {
        let beam = SCNNode(geometry: SCNCylinder(radius: 0.01, height: 0.5))
        beam.geometry?.firstMaterial = makeEmissiveMaterial(color.withAlphaComponent(0.3))
        beam.position = SCNVector3(0, 0.35, 0)
        root.addChildNode(beam)
    }

    private static func addBaseGlow(on root: SCNNode, color: UIColor) {
        let light = SCNLight()
        light.type = .omni
        light.color = color
        light.intensity = 200
        light.attenuationStartDistance = 0
        light.attenuationEndDistance = 1.5
        let n = SCNNode()
        n.light = light
        n.position = SCNVector3(0, 0.15, 0)
        root.addChildNode(n)
    }

    private static func addFloatAndSpin(on root: SCNNode) {
        let bob = SCNAction.repeatForever(.sequence([
            .move(by: SCNVector3(0, 0.04, 0), duration: 0.8),
            .move(by: SCNVector3(0, -0.04, 0), duration: 0.8)
        ]))
        let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0))
        root.runAction(.group([bob, spin]))
    }

    // MARK: - Materials

    private static func makeGlowMaterial(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = 1.0
        m.lightingModel = .constant
        m.transparency = 0.85
        return m
    }

    private static func makeEmissiveMaterial(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = 2.0
        m.lightingModel = .constant
        return m
    }
}
