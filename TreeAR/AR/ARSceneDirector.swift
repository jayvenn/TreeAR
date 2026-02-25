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
    private var executeAnimationVariant: Int = 0

    // MARK: - Spirit Chase

    private(set) var spiritNode: SCNNode?

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

        let boss = HollowBoss.buildModel()
        boss.position = SCNVector3(0, -HollowBoss.height, 0)
        boss.opacity = 0
        tracker.addChildNode(boss)
        self.bossNode = boss

        telegraphRenderer.configure(parentNode: boss)

        boss.runAction(HollowBoss.spawnAnimation(),
                       completionHandler: mainThreadCompletion(completion))
    }

    // MARK: - Per-Frame

    /// Slides the boss toward the player's XZ position at the given speed.
    func advanceBossToward(cameraTransform: simd_float4x4, speed: Float, deltaTime: Float) {
        guard let boss = bossNode, let tracker = trackerNode else { return }

        let bossWorld = boss.worldPosition
        let camX = cameraTransform.columns.3.x
        let camZ = cameraTransform.columns.3.z

        let dx = camX - bossWorld.x
        let dz = camZ - bossWorld.z
        let dist = sqrt(dx * dx + dz * dz)
        guard dist > 0.4 else { return }

        let step = min(speed * deltaTime, dist - 0.4)
        let nx = dx / dist
        let nz = dz / dist

        let worldDelta = SCNVector3(nx * step, 0, nz * step)
        let curLocal = boss.position
        let curWorld = tracker.convertPosition(curLocal, to: nil)
        let targetWorld = SCNVector3(curWorld.x + worldDelta.x, curWorld.y, curWorld.z + worldDelta.z)
        let targetLocal = tracker.convertPosition(targetWorld, from: nil)

        boss.position = SCNVector3(targetLocal.x, curLocal.y, targetLocal.z)
    }

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

        let variant = executeAnimationVariant % 3
        executeAnimationVariant += 1

        switch attack {
        case .groundSlam:
            let a = HollowBoss.groundSlamExecuteAnimation(variant: variant)
            boss.childNode(withName: "arm_left", recursively: true)?.runAction(a.left)
            boss.childNode(withName: "arm_right", recursively: true)?.runAction(a.right)
        case .sweep:
            boss.childNode(withName: "arm_right", recursively: true)?
                .runAction(HollowBoss.sweepExecuteAnimation(variant: variant))
        case .stompWave:
            boss.childNode(withName: "leg_left", recursively: true)?
                .runAction(HollowBoss.stompExecuteAnimation(variant: variant))
        case .enragedCombo:
            let a = HollowBoss.groundSlamExecuteAnimation(variant: variant)
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
        for child in boss.childNodes where child.name != "eye" {
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
            light.color = UIColor(red: 1, green: 0.3, blue: 0, alpha: 1)
            light.intensity = 200
            light.attenuationEndDistance = 1.5
            let n = SCNNode()
            n.light = light
            n.position = SCNVector3(0, 1.2, 0)
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

    // MARK: - Spirit Chase

    func spawnSpirit(at worldPosition: SCNVector3) {
        assertMainThread()
        guard let tracker = trackerNode else { return }

        let spirit = SCNNode()
        spirit.name = "spirit"
        spirit.renderingOrder = 200

        // Bright inner core — highly visible
        let core = SCNNode(geometry: SCNSphere(radius: 0.35))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 1.0, green: 0.55, blue: 0.1, alpha: 1)
        mat.emission.contents = UIColor(red: 1.0, green: 0.45, blue: 0.05, alpha: 1)
        mat.emission.intensity = 2.5
        mat.lightingModel = .constant
        mat.transparency = 0.75
        mat.readsFromDepthBuffer = false
        core.geometry?.firstMaterial = mat
        core.name = "spirit_core"
        spirit.addChildNode(core)

        // Large outer glow halo
        let halo = SCNNode(geometry: SCNSphere(radius: 0.6))
        let haloMat = SCNMaterial()
        haloMat.diffuse.contents = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
        haloMat.emission.contents = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
        haloMat.emission.intensity = 1.5
        haloMat.lightingModel = .constant
        haloMat.transparency = 0.25
        haloMat.writesToDepthBuffer = false
        haloMat.readsFromDepthBuffer = false
        halo.geometry?.firstMaterial = haloMat
        halo.name = "spirit_halo"
        spirit.addChildNode(halo)

        // Omni light so it illuminates nearby surfaces
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1)
        light.intensity = 400
        light.attenuationEndDistance = 3.5
        spirit.light = light

        // Dense particle trail for visibility and motion
        let trail = SCNParticleSystem()
        trail.birthRate = 60
        trail.particleLifeSpan = 0.8
        trail.particleSize = 0.06
        trail.particleSizeVariation = 0.02
        trail.particleColor = UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 0.85)
        trail.particleColorVariation = SCNVector4(0, 0.1, 0.05, 0.1)
        trail.emitterShape = SCNSphere(radius: 0.15)
        trail.particleVelocity = 0.05
        trail.spreadingAngle = 180
        trail.blendMode = .additive
        trail.isLightingEnabled = false
        spirit.addParticleSystem(trail)

        // Breathing pulse + gentle hover bob
        let pulse = SCNAction.repeatForever(.sequence([
            .scale(to: 1.15, duration: 0.6),
            .scale(to: 0.88, duration: 0.6)
        ]))
        let hover = SCNAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 0.08, z: 0, duration: 0.9),
            .moveBy(x: 0, y: -0.08, z: 0, duration: 0.9)
        ]))
        spirit.runAction(pulse, forKey: "pulse")
        spirit.runAction(hover, forKey: "hover")

        let localPos = tracker.convertPosition(worldPosition, from: nil)
        let riseStartY = localPos.y - 0.4
        let riseEndY = localPos.y + 1.2
        spirit.position = SCNVector3(localPos.x, riseStartY, localPos.z)
        spirit.opacity = 0
        tracker.addChildNode(spirit)
        self.spiritNode = spirit

        let riseDuration: TimeInterval = 1.8
        let rise = SCNAction.move(to: SCNVector3(localPos.x, riseEndY, localPos.z), duration: riseDuration)
        rise.timingMode = .easeOut
        let fadeIn = SCNAction.fadeIn(duration: riseDuration * 0.5)
        spirit.runAction(.group([rise, fadeIn]))
    }

    /// Plays a bright flash on the spirit to signal a backoff touch.
    func playSpiritBackoffEffect() {
        guard let spirit = spiritNode else { return }
        let flash = SCNAction.sequence([
            .customAction(duration: 0.15) { node, t in
                let frac = Float(t / 0.15)
                node.childNodes.forEach { child in
                    child.geometry?.firstMaterial?.emission.intensity = CGFloat(2.5 + frac * 4.0)
                }
            },
            .customAction(duration: 0.35) { node, t in
                let frac = Float(t / 0.35)
                node.childNodes.forEach { child in
                    child.geometry?.firstMaterial?.emission.intensity = CGFloat(6.5 - frac * 4.0)
                }
            }
        ])
        spirit.runAction(flash, forKey: "backoff_flash")
    }

    /// Moves the spirit toward the player. Returns distance to player.
    @discardableResult
    func advanceSpiritToward(cameraTransform: simd_float4x4, speed: Float, deltaTime: Float) -> Float {
        guard let spirit = spiritNode, let tracker = trackerNode else { return .greatestFiniteMagnitude }

        let spiritWorld = spirit.worldPosition
        let camX = cameraTransform.columns.3.x
        let camY = cameraTransform.columns.3.y
        let camZ = cameraTransform.columns.3.z

        let dx = camX - spiritWorld.x
        let dy = camY - spiritWorld.y
        let dz = camZ - spiritWorld.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)
        guard dist > 0.3 else { return dist }

        let step = min(speed * deltaTime, dist - 0.3)
        let nx = dx / dist
        let ny = dy / dist
        let nz = dz / dist

        let curLocal = spirit.position
        let curWorld = tracker.convertPosition(curLocal, to: nil)
        let targetWorld = SCNVector3(curWorld.x + nx * step, curWorld.y + ny * step, curWorld.z + nz * step)
        let targetLocal = tracker.convertPosition(targetWorld, from: nil)
        spirit.position = targetLocal

        return dist
    }

    /// Moves the spirit away from the player (e.g. after a touch). Returns new distance to player.
    @discardableResult
    func retreatSpirit(from cameraTransform: simd_float4x4, speed: Float, deltaTime: Float) -> Float {
        guard let spirit = spiritNode, let tracker = trackerNode else { return .greatestFiniteMagnitude }

        let spiritWorld = spirit.worldPosition
        let camX = cameraTransform.columns.3.x
        let camY = cameraTransform.columns.3.y
        let camZ = cameraTransform.columns.3.z

        let dx = camX - spiritWorld.x
        let dy = camY - spiritWorld.y
        let dz = camZ - spiritWorld.z
        let dist = sqrt(dx * dx + dy * dy + dz * dz)
        guard dist > 0.01 else { return dist }

        let nx = dx / dist
        let ny = dy / dist
        let nz = dz / dist

        let step = speed * deltaTime
        let curLocal = spirit.position
        let curWorld = tracker.convertPosition(curLocal, to: nil)
        let targetWorld = SCNVector3(curWorld.x - nx * step, curWorld.y - ny * step, curWorld.z - nz * step)
        let targetLocal = tracker.convertPosition(targetWorld, from: nil)
        spirit.position = targetLocal

        let newDx = camX - targetWorld.x
        let newDy = camY - targetWorld.y
        let newDz = camZ - targetWorld.z
        return sqrt(newDx * newDx + newDy * newDy + newDz * newDz)
    }

    func removeSpirit() {
        spiritNode?.removeAllActions()
        spiritNode?.removeAllParticleSystems()
        spiritNode?.removeFromParentNode()
        spiritNode = nil
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
