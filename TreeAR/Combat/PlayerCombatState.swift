//
//  PlayerCombatState.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Mutable value type tracking the player's combat stats for one fight session.
struct PlayerCombatState {

    // MARK: - Configuration

    let maxHP: Int = 100
    let baseAttackDamage: Int = 10
    let baseAttackCooldown: TimeInterval = 0.55
    let attackRange: Float = 1.5
    let invulnerabilityDuration: TimeInterval = 1.0
    let healAmount: Int = 40

    // MARK: - Machine Gun Mode

    let machineGunDamage: Int = 6
    let machineGunCooldown: TimeInterval = 0.12
    let machineGunDuration: TimeInterval = 8.0
    private(set) var machineGunTimer: TimeInterval = 0
    var isMachineGunActive: Bool { machineGunTimer > 0 }
    var machineGunFraction: Float { Float(machineGunTimer / machineGunDuration) }

    // MARK: - Computed

    var attackDamage: Int { isMachineGunActive ? machineGunDamage : baseAttackDamage }
    var attackCooldown: TimeInterval { isMachineGunActive ? machineGunCooldown : baseAttackCooldown }

    // MARK: - Runtime

    private(set) var currentHP: Int
    var lastAttackTime: TimeInterval = 0
    private(set) var isInvulnerable: Bool = false
    private var invulnerabilityTimer: TimeInterval = 0

    var isAlive: Bool { currentHP > 0 }
    var hpFraction: Float { Float(currentHP) / Float(maxHP) }

    // MARK: - Init

    init() {
        self.currentHP = maxHP
    }

    // MARK: - Queries

    func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    // MARK: - Mutations

    mutating func recordAttack(at time: TimeInterval) {
        lastAttackTime = time
    }

    mutating func takeDamage(_ amount: Int) {
        guard !isInvulnerable else { return }
        currentHP = max(0, currentHP - amount)
        isInvulnerable = true
        invulnerabilityTimer = invulnerabilityDuration
    }

    mutating func heal(_ amount: Int) {
        currentHP = min(maxHP, currentHP + amount)
    }

    mutating func activateMachineGun() {
        machineGunTimer = machineGunDuration
    }

    mutating func update(deltaTime dt: TimeInterval) {
        if isInvulnerable {
            invulnerabilityTimer -= dt
            if invulnerabilityTimer <= 0 { isInvulnerable = false }
        }
        if machineGunTimer > 0 {
            machineGunTimer -= dt
            if machineGunTimer < 0 { machineGunTimer = 0 }
        }
    }

    mutating func reset() {
        currentHP = maxHP
        lastAttackTime = 0
        isInvulnerable = false
        invulnerabilityTimer = 0
        machineGunTimer = 0
    }
}
