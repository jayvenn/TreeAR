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
    let attackDamage: Int = 10
    let attackCooldown: TimeInterval = 0.55
    /// Horizontal meters from boss center within which taps deal damage.
    let attackRange: Float = 1.5
    let invulnerabilityDuration: TimeInterval = 1.0

    // MARK: - Runtime

    var currentHP: Int = 100
    var lastAttackTime: TimeInterval = 0
    var isInvulnerable: Bool = false
    private var invulnerabilityTimer: TimeInterval = 0

    var isAlive: Bool { currentHP > 0 }
    var hpFraction: Float { Float(currentHP) / Float(maxHP) }

    // MARK: - Mutations

    /// Returns `true` if the cooldown allows an attack right now.
    mutating func canAttack(at time: TimeInterval) -> Bool {
        time - lastAttackTime >= attackCooldown
    }

    mutating func recordAttack(at time: TimeInterval) {
        lastAttackTime = time
    }

    mutating func takeDamage(_ amount: Int) {
        guard !isInvulnerable else { return }
        currentHP = max(0, currentHP - amount)
        isInvulnerable = true
        invulnerabilityTimer = invulnerabilityDuration
    }

    /// Called every frame. Ticks down invulnerability.
    mutating func update(deltaTime dt: TimeInterval) {
        if isInvulnerable {
            invulnerabilityTimer -= dt
            if invulnerabilityTimer <= 0 {
                isInvulnerable = false
            }
        }
    }

    mutating func reset() {
        currentHP = maxHP
        lastAttackTime = 0
        isInvulnerable = false
        invulnerabilityTimer = 0
    }
}
