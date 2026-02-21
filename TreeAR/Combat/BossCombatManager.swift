//
//  BossCombatManager.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

/// Outcome events the combat manager fires back to the ViewModel.
protocol BossCombatDelegate: AnyObject {
    func combatManager(_ manager: BossCombatManager, bossDidSelectAttack attack: BossAttack)
    func combatManager(_ manager: BossCombatManager, bossDidExecuteAttack attack: BossAttack)
    func combatManager(_ manager: BossCombatManager, bossDidFinishRecoveryFrom attack: BossAttack)
    func combatManager(_ manager: BossCombatManager, bossDidEnterPhase phase: BossPhase)
    func combatManagerBossDidDie(_ manager: BossCombatManager)
    func combatManager(_ manager: BossCombatManager, bossDidTaunt: Void)
}

/// Manages the boss AI state machine and HP for one fight.
///
/// The manager runs on a tick-based model: the owner calls `update(deltaTime:playerDistance:)`
/// every frame. All state transitions and delegate calls happen synchronously within that call.
final class BossCombatManager {

    // MARK: - AI State

    enum AIState: Equatable {
        case idle
        case telegraphing(BossAttack)
        case executing(BossAttack)
        case recovering(BossAttack)
        case taunting
        case dying
        case dead
    }

    // MARK: - Configuration

    let maxHP: Int = 600
    private(set) var currentHP: Int = 600

    /// Distance beyond which the boss taunts instead of attacking.
    let tauntThreshold: Float = 4.0

    // MARK: - State

    private(set) var aiState: AIState = .idle
    private(set) var phase: BossPhase = .phase1
    private var stateTimer: TimeInterval = 0
    private var lastAttack: BossAttack?
    private var phaseTransitioned: Set<BossPhase> = [.phase1]
    var isExecutingAttack: Bool {
        if case .executing = aiState { return true }
        return false
    }
    var currentAttack: BossAttack? {
        switch aiState {
        case .telegraphing(let a), .executing(let a), .recovering(let a): return a
        default: return nil
        }
    }

    var hpFraction: Float { Float(currentHP) / Float(maxHP) }
    var isAlive: Bool { currentHP > 0 }

    weak var delegate: BossCombatDelegate?

    // MARK: - Public API

    func takeDamage(_ amount: Int) {
        guard isAlive else { return }
        currentHP = max(0, currentHP - amount)
        updatePhase()
        if currentHP == 0 {
            enterState(.dying)
            delegate?.combatManagerBossDidDie(self)
        }
    }

    /// Drive the AI forward by one frame.
    func update(deltaTime dt: TimeInterval, playerDistance: Float) {
        guard isAlive else { return }
        stateTimer -= dt

        switch aiState {
        case .idle:
            if stateTimer <= 0 {
                if playerDistance > tauntThreshold {
                    enterState(.taunting)
                    delegate?.combatManager(self, bossDidTaunt: ())
                } else {
                    let attack = selectAttack()
                    enterState(.telegraphing(attack))
                    delegate?.combatManager(self, bossDidSelectAttack: attack)
                }
            }

        case .telegraphing(let attack):
            if stateTimer <= 0 {
                enterState(.executing(attack))
                delegate?.combatManager(self, bossDidExecuteAttack: attack)
            }

        case .executing(let attack):
            if stateTimer <= 0 {
                enterState(.recovering(attack))
            }

        case .recovering(let attack):
            if stateTimer <= 0 {
                lastAttack = attack
                delegate?.combatManager(self, bossDidFinishRecoveryFrom: attack)
                enterIdleWithDelay()
            }

        case .taunting:
            if stateTimer <= 0 {
                enterIdleWithDelay()
            }

        case .dying, .dead:
            break
        }
    }

    func reset() {
        currentHP = maxHP
        aiState = .idle
        phase = .phase1
        stateTimer = 0
        lastAttack = nil
        phaseTransitioned = [.phase1]
    }

    func beginFight() {
        enterIdleWithDelay()
    }

    // MARK: - Private

    private func enterState(_ state: AIState) {
        aiState = state
        switch state {
        case .idle:
            break
        case .telegraphing(let a):
            stateTimer = a.telegraphDuration
        case .executing(let a):
            stateTimer = a.executeDuration
        case .recovering(let a):
            stateTimer = a.recoveryDuration
        case .taunting:
            stateTimer = 2.0
        case .dying:
            stateTimer = 3.0
        case .dead:
            break
        }
    }

    private func enterIdleWithDelay() {
        aiState = .idle
        let range = phase.idleDurationRange
        stateTimer = TimeInterval.random(in: range)
    }

    private func selectAttack() -> BossAttack {
        let available = BossAttack.allCases.filter { $0.minimumPhase <= phase && $0 != lastAttack }
        return available.randomElement() ?? .groundSlam
    }

    private func updatePhase() {
        let newPhase: BossPhase
        let fraction = hpFraction
        if fraction <= 0.30 {
            newPhase = .phase3
        } else if fraction <= 0.60 {
            newPhase = .phase2
        } else {
            newPhase = .phase1
        }

        if newPhase != phase, !phaseTransitioned.contains(newPhase) {
            phase = newPhase
            phaseTransitioned.insert(newPhase)
            delegate?.combatManager(self, bossDidEnterPhase: newPhase)
        }
    }
}
