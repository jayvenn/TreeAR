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
/// Completion handlers are **always** delivered on the main thread.
final class ARSceneDirector {

    // MARK: - Pre-loaded nodes

    private lazy var grassNode: SCNNode = .grass
    private lazy var lightsNode: SCNNode = .lights

    // MARK: - Runtime state

    private weak var trackerNode: SCNNode?
    private(set) var bossNode: SCNNode?
    let telegraphRenderer = BossTelegraphRenderer()

    // MARK: - Weapon

    private(set) var weaponNode: SCNNode?
    private var isSwinging = false
    private(set) var isMachineGunMode = false

    // MARK: - Loot

    private var activeLootNodes: [SCNNode] = []

    // MARK: - Setup

    func preloadAssets() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            _ = self.grassNode
            _ = self.lightsNode
        }
    }

    func configure(trackerNode: SCNNode) {
        assertMainThread()
        self.trackerNode = trackerNode
    }

    // MARK: - Grass

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

    func dismissGrass(completion: @escaping () -> Void) {
        assertMainThread()
        grassNode.runAction(.grassShrinkSequenceAction(grassNode))
        grassNode.runAction(.grassShrinkFadeOutSequenceAction())
        for child in grassNode.childNodes { child.runAction(.grassReversedRotation) }
        lightsNode.runAction(.sequence([.fadeOut(duration: 1.0), .removeFromParentNode()]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: completion)
    }

    // MARK: - Weapon Management

    /// Builds and attaches the weapon to the camera (pointOfView) node.
    func attachWeapon(to cameraNode: SCNNode) {
        assertMainThread()
        guard weaponNode == nil else { return }

        let weapon = PlayerWeapon.buildModel()
        weapon.position = PlayerWeapon.restPosition
        weapon.eulerAngles = PlayerWeapon.restEuler
        cameraNode.addChildNode(weapon)
        self.weaponNode = weapon

        weapon.runAction(PlayerWeapon.idleSwayAnimation(), forKey: PlayerWeapon.idleSwayKey)
    }

    func removeWeapon() {
        weaponNode?.removeAllActions()
        weaponNode?.removeFromParentNode()
        weaponNode = nil
        isSwinging = false
        isMachineGunMode = false
    }

    /// Resets swing/mode flags and restores the idle sway without removing the weapon.
    func resetWeaponState() {
        isSwinging = false
        isMachineGunMode = false
        guard let weapon = weaponNode else { return }
        weapon.removeAllActions()
        weapon.position = PlayerWeapon.restPosition
        weapon.eulerAngles = PlayerWeapon.restEuler
        weapon.runAction(PlayerWeapon.idleSwayAnimation(), forKey: PlayerWeapon.idleSwayKey)
    }

    /// Triggers a weapon swing. Returns `false` if already mid-swing.
    /// `onApex` fires at the moment the blade reaches max extension (hit-check time).
    /// `onComplete` fires when the swing fully returns to rest.
    func swingWeapon(onApex: @escaping () -> Void, onComplete: @escaping () -> Void) -> Bool {
        assertMainThread()
        guard let weapon = weaponNode, !isSwinging else { return false }
        isSwinging = true

        weapon.removeAction(forKey: PlayerWeapon.idleSwayKey)
        PlayerWeapon.spawnSlashTrail(on: weapon)

        let swing = PlayerWeapon.swingAnimation(onApex: { [weak self] in
            DispatchQueue.main.async {
                onApex()
            }
        })

        weapon.runAction(swing, completionHandler: mainThreadCompletion { [weak self] in
            guard let self else { return }
            self.isSwinging = false
            weapon.runAction(PlayerWeapon.idleSwayAnimation(), forKey: PlayerWeapon.idleSwayKey)
            onComplete()
        })

        return true
    }

    /// Flares weapon runes on a successful hit.
    func playWeaponHitFlare() {
        guard let weapon = weaponNode else { return }
        for child in weapon.childNodes {
            child.runAction(.sequence([
                PlayerWeapon.hitFlareAnimation(),
                PlayerWeapon.hitFlareResetAnimation()
            ]))
        }
    }

    // MARK: - Boss Spawn

    func spawnBoss(completion: @escaping () -> Void) {
        assertMainThread()
        guard let tracker = trackerNode else { return }

        addAtmosphericLighting(on: tracker)

        let boss = HollowBoss.buildModel()
        boss.position = SCNVector3(0, -HollowBoss.height, 0)
        boss.opacity = 0
        tracker.addChildNode(boss)
        self.bossNode = boss

        telegraphRenderer.configure(parentNode: boss)

        addSpawnGroundEffect(on: tracker)

        boss.runAction(HollowBoss.spawnAnimation(),
                       completionHandler: mainThreadCompletion(completion))
    }

    // MARK: - Per-Frame

    func updateBossFacing(cameraTransform: simd_float4x4) {
        guard let boss = bossNode else { return }
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let bossPos = boss.worldPosition
        let angle = atan2(camX - bossPos.x, camZ - bossPos.z)
        boss.eulerAngles.y = angle
    }

    func distanceToBoss(cameraTransform: simd_float4x4) -> Float {
        guard let boss = bossNode else { return .greatestFiniteMagnitude }
        let dx = cameraTransform.columns.3.x - boss.worldPosition.x
        let dz = cameraTransform.columns.3.z - boss.worldPosition.z
        return sqrt(dx * dx + dz * dz)
    }

    func isCameraBehindBoss(cameraTransform: simd_float4x4) -> Bool {
        guard let boss = bossNode else { return false }
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z
        let bossPos = boss.worldPosition
        let fwd = SCNVector3(-sin(boss.eulerAngles.y), 0, -cos(boss.eulerAngles.y))
        let toCam = SCNVector3(camX - bossPos.x, 0, camZ - bossPos.z)
        return fwd.x * toCam.x + fwd.z * toCam.z < 0
    }

    // MARK: - Boss Attack Animations

    func playTelegraphAnimation(for attack: BossAttack) {
        guard let boss = bossNode else { return }
        telegraphRenderer.showTelegraph(for: attack, duration: attack.telegraphDuration)

        switch attack {
        case .groundSlam:
            let a = HollowBoss.groundSlamTelegraphAnimation(duration: attack.telegraphDuration)
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(a.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(a.right)
        case .sweep:
            boss.childNode(withName: "arm_right", recursively: true)?
                .runAction(HollowBoss.sweepTelegraphAnimation(duration: attack.telegraphDuration))
        case .stompWave:
            boss.childNode(withName: "leg_left", recursively: true)?
                .runAction(HollowBoss.stompTelegraphAnimation(duration: attack.telegraphDuration))
        case .enragedCombo:
            let a = HollowBoss.groundSlamTelegraphAnimation(duration: attack.telegraphDuration * 0.7)
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(a.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(a.right)
        }
    }

    func playExecuteAnimation(for attack: BossAttack) {
        guard let boss = bossNode else { return }
        telegraphRenderer.flashAndRemoveTelegraphs()

        switch attack {
        case .groundSlam:
            let a = HollowBoss.groundSlamExecuteAnimation()
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(a.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(a.right)
        case .sweep:
            boss.childNode(withName: "arm_right", recursively: true)?
                .runAction(HollowBoss.sweepExecuteAnimation())
        case .stompWave:
            boss.childNode(withName: "leg_left", recursively: true)?
                .runAction(HollowBoss.stompExecuteAnimation())
        case .enragedCombo:
            let a = HollowBoss.groundSlamExecuteAnimation()
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(a.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(a.right)
        }

        spawnImpactParticles()
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

    // MARK: - Hit Feedback

    func playBossHitEffect() {
        guard let boss = bossNode else { return }
        for child in boss.childNodes where child.name != "eye" && child.name != "ambient_particles" {
            child.runAction(HollowBoss.hitFlashAnimation())
        }
        boss.runAction(HollowBoss.hitStaggerAnimation())
        spawnHitSparks()
    }

    func playEnrageEffect(phase: BossPhase) {
        guard let boss = bossNode else { return }
        for child in boss.childNodes {
            child.runAction(HollowBoss.enrageAnimation())
        }

        if phase == .phase3 {
            let light = SCNLight()
            light.type = .omni
            light.color = UIColor(red: 1, green: 0.15, blue: 0, alpha: 1)
            light.intensity = 600
            let n = SCNNode()
            n.light = light
            n.position = SCNVector3(0, 1.5, 0)
            boss.addChildNode(n)
        }
    }

    func playBossDeathAnimation(completion: @escaping () -> Void) {
        guard let boss = bossNode else {
            completion()
            return
        }
        telegraphRenderer.removeAllTelegraphs()
        spawnDeathExplosion()
        boss.runAction(HollowBoss.deathAnimation(),
                       completionHandler: mainThreadCompletion(completion))
    }

    func removeBoss() {
        bossNode?.removeFromParentNode()
        bossNode = nil
    }

    // MARK: - Loot

    /// Spawns a loot node at a random position 2-3m from the boss on the ground plane.
    func spawnLoot(type: LootType) {
        assertMainThread()
        guard let tracker = trackerNode, let boss = bossNode else { return }

        let angle = Float.random(in: 0 ... .pi * 2)
        let dist  = Float.random(in: 1.8 ... 3.0)
        let bossPos = boss.position
        let x = bossPos.x + cos(angle) * dist
        let z = bossPos.z + sin(angle) * dist

        let node = LootNodeBuilder.build(type: type)
        node.position = SCNVector3(x, 0.0, z)
        node.opacity = 0
        tracker.addChildNode(node)
        activeLootNodes.append(node)

        let appear = SCNAction.sequence([
            .scale(to: 0.3, duration: 0),
            .group([.fadeIn(duration: 0.4), .scale(to: 1.0, duration: 0.4)])
        ])
        node.runAction(appear)

        let despawn = SCNAction.sequence([
            .wait(duration: type.despawnTime),
            .group([.fadeOut(duration: 0.5), .scale(to: 0.3, duration: 0.5)]),
            .removeFromParentNode()
        ])
        node.runAction(despawn, forKey: "despawn")
    }

    /// Returns the loot type if a node name matches a loot drop, else nil.
    func lootType(forNodeName name: String) -> LootType? {
        LootType.allCases.first { $0.nodeName == name }
    }

    /// Distance from camera to a loot node by name. Returns nil if not found.
    func distanceToLoot(named name: String, cameraTransform: simd_float4x4) -> Float? {
        guard let node = activeLootNodes.first(where: { $0.name == name }) else { return nil }
        let pos = node.worldPosition
        let dx = cameraTransform.columns.3.x - pos.x
        let dz = cameraTransform.columns.3.z - pos.z
        return sqrt(dx * dx + dz * dz)
    }

    /// Plays pickup effect and removes the loot node.
    func pickupLoot(named name: String) {
        guard let idx = activeLootNodes.firstIndex(where: { $0.name == name }) else { return }
        let node = activeLootNodes.remove(at: idx)
        node.removeAction(forKey: "despawn")
        let pickup = SCNAction.group([
            .scale(to: 1.5, duration: 0.15),
            .fadeOut(duration: 0.15)
        ])
        node.runAction(.sequence([pickup, .removeFromParentNode()]))
    }

    func removeAllLoot() {
        for node in activeLootNodes {
            node.removeFromParentNode()
        }
        activeLootNodes.removeAll()
    }

    // MARK: - Machine Gun Weapon Mode

    func activateMachineGunMode() {
        guard let weapon = weaponNode else { return }
        isMachineGunMode = true
        PlayerWeapon.activateMachineGunVisual(on: weapon)
    }

    func deactivateMachineGunMode() {
        guard let weapon = weaponNode else { return }
        isMachineGunMode = false
        PlayerWeapon.deactivateMachineGunVisual(on: weapon)
    }

    /// Rapid jab for machine gun mode. Returns false if mid-swing.
    func rapidJabWeapon(onApex: @escaping () -> Void, onComplete: @escaping () -> Void) -> Bool {
        assertMainThread()
        guard let weapon = weaponNode, !isSwinging else { return false }
        isSwinging = true

        weapon.removeAction(forKey: PlayerWeapon.idleSwayKey)
        PlayerWeapon.spawnRapidTrail(on: weapon)

        let jab = PlayerWeapon.rapidJabAnimation(onApex: {
            DispatchQueue.main.async { onApex() }
        })

        weapon.runAction(jab, completionHandler: mainThreadCompletion { [weak self] in
            guard let self else { return }
            self.isSwinging = false
            onComplete()
        })
        return true
    }

    // MARK: - Hit Testing

    func hitNodeName(at location: CGPoint, in sceneView: ARSCNView) -> String? {
        sceneView.hitTest(location).first?.node.name
    }

    /// Walks up the node hierarchy to find a named ancestor (for loot child hit).
    func rootLootName(at location: CGPoint, in sceneView: ARSCNView) -> String? {
        guard let hit = sceneView.hitTest(location).first else { return nil }
        var node: SCNNode? = hit.node
        while let n = node {
            if let type = lootType(forNodeName: n.name ?? "") { return type.nodeName }
            node = n.parent
        }
        return nil
    }

    // MARK: - Private — Particles & Effects

    private func spawnHitSparks() {
        guard let boss = bossNode else { return }
        let sparkNode = SCNNode()
        sparkNode.position = SCNVector3(0, 1.2, 0.3)

        let sparks = SCNParticleSystem()
        sparks.birthRate = 80
        sparks.particleLifeSpan = 0.3
        sparks.particleSize = 0.015
        sparks.particleColor = UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)
        sparks.emitterShape = SCNSphere(radius: 0.1)
        sparks.particleVelocity = 1.5
        sparks.spreadingAngle = 120
        sparks.blendMode = .additive
        sparks.isLightingEnabled = false
        sparks.loops = false
        sparks.emissionDuration = 0.08

        sparkNode.addParticleSystem(sparks)
        boss.addChildNode(sparkNode)
        sparkNode.runAction(.sequence([.wait(duration: 0.5), .removeFromParentNode()]))
    }

    private func spawnImpactParticles() {
        guard let boss = bossNode else { return }
        let node = SCNNode()
        node.position = SCNVector3(0, 0.02, 0)

        let dust = SCNParticleSystem()
        dust.birthRate = 40
        dust.particleLifeSpan = 0.8
        dust.particleSize = 0.06
        dust.particleSizeVariation = 0.04
        dust.particleColor = UIColor(white: 0.5, alpha: 0.4)
        dust.emitterShape = SCNCylinder(radius: 1.5, height: 0.01)
        dust.particleVelocity = 0.8
        dust.spreadingAngle = 90
        dust.blendMode = .alpha
        dust.isLightingEnabled = false
        dust.loops = false
        dust.emissionDuration = 0.15

        node.addParticleSystem(dust)
        boss.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 1.5), .removeFromParentNode()]))
    }

    private func spawnDeathExplosion() {
        guard let boss = bossNode else { return }
        let node = SCNNode()
        node.position = SCNVector3(0, 1.1, 0)

        let explosion = SCNParticleSystem()
        explosion.birthRate = 200
        explosion.particleLifeSpan = 1.5
        explosion.particleLifeSpanVariation = 0.5
        explosion.particleSize = 0.04
        explosion.particleSizeVariation = 0.03
        explosion.particleColor = UIColor(red: 1, green: 0.3, blue: 0.05, alpha: 1)
        explosion.particleColorVariation = SCNVector4(0.1, 0.2, 0, 0.3)
        explosion.emitterShape = SCNSphere(radius: 0.5)
        explosion.particleVelocity = 2.0
        explosion.particleVelocityVariation = 1.0
        explosion.spreadingAngle = 180
        explosion.blendMode = .additive
        explosion.isLightingEnabled = false
        explosion.loops = false
        explosion.emissionDuration = 0.4

        node.addParticleSystem(explosion)
        boss.addChildNode(node)
    }

    private func addSpawnGroundEffect(on tracker: SCNNode) {
        let node = SCNNode()
        node.position = SCNVector3(0, 0.01, 0)

        let crack = SCNParticleSystem()
        crack.birthRate = 30
        crack.particleLifeSpan = 2.5
        crack.particleSize = 0.03
        crack.particleColor = UIColor(red: 1, green: 0.25, blue: 0.05, alpha: 0.8)
        crack.emitterShape = SCNCylinder(radius: 0.8, height: 0.01)
        crack.particleVelocity = 0.3
        crack.spreadingAngle = 30
        crack.blendMode = .additive
        crack.isLightingEnabled = false
        crack.loops = false
        crack.emissionDuration = 3.0

        node.addParticleSystem(crack)
        tracker.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 5), .removeFromParentNode()]))
    }

    private func addAtmosphericLighting(on tracker: SCNNode) {
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .omni
        ambient.color = UIColor(red: 1, green: 0.15, blue: 0, alpha: 1)
        ambient.intensity = 150
        ambient.attenuationStartDistance = 0
        ambient.attenuationEndDistance = 4.0
        ambientNode.light = ambient
        ambientNode.position = SCNVector3(0, 0.5, 0)
        tracker.addChildNode(ambientNode)

        let fadeUp = SCNAction.customAction(duration: 3.0) { node, elapsed in
            let t = elapsed / 3.0
            node.light?.intensity = CGFloat(t) * 150
        }
        ambientNode.runAction(fadeUp)
    }

    // MARK: - Private — Threading

    private func mainThreadCompletion(_ block: @escaping () -> Void) -> () -> Void {
        return {
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        }
    }

    private func assertMainThread(function: StaticString = #function) {
        assert(Thread.isMainThread,
               "ARSceneDirector.\(function) must be called on the main thread.")
    }
}
