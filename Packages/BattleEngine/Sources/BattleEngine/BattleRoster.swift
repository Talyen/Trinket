import Foundation
import TrinketContent
import TrinketCore

public enum BattleParticipant: CaseIterable, Sendable {
    case hero
    case pet
    case enemy

    /// Participants in effect-tick order for each end-of-round pass.
    public static let effectTickOrder: [BattleParticipant] = [.enemy, .hero, .pet]

    public var isPartyMember: Bool {
        switch self {
        case .hero, .pet: return true
        case .enemy: return false
        }
    }
}

/// Collection of the three `CombatantRuntime`s participating in a battle:
/// the hero, the pet, and the enemy. Provides dispatch by role or by
/// `Combatant` identity.
///
/// The roster is the single source of truth for per-combatant mutable state
/// (health, active effects, action counts). `BattleState` delegates to it.
public struct BattleRoster {
    public var hero: CombatantRuntime
    public var pet: CombatantRuntime
    public var enemy: CombatantRuntime

    public init(hero: CombatantRuntime, pet: CombatantRuntime, enemy: CombatantRuntime) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
    }

    /// All three runtimes, in role order (hero, pet, enemy).
    public var allRuntimes: [CombatantRuntime] {
        [hero, pet, enemy]
    }

    public subscript(participant: BattleParticipant) -> CombatantRuntime {
        get {
            switch participant {
            case .hero: return hero
            case .pet: return pet
            case .enemy: return enemy
            }
        }
        set {
            switch participant {
            case .hero: hero = newValue
            case .pet: pet = newValue
            case .enemy: enemy = newValue
            }
        }
    }

    public func participant(for combatant: Combatant) -> BattleParticipant? {
        if hero.id == combatant.id { return .hero }
        if pet.id == combatant.id { return .pet }
        if enemy.id == combatant.id { return .enemy }
        return nil
    }

    // MARK: - Dispatch by Combatant identity

    /// Returns the runtime whose `id` matches `combatant.id`, if any.
    public func runtime(for combatant: Combatant) -> CombatantRuntime? {
        participant(for: combatant).map { self[$0] }
    }

    /// Returns the runtime with the given `id`, if any.
    public func combatant(for id: String) -> CombatantRuntime? {
        allRuntimes.first { $0.id == id }
    }

    /// Replaces the runtime whose `id` matches `runtime.id`.
    public mutating func update(_ runtime: CombatantRuntime) {
        guard let participant = participant(for: runtime.combatant) else { return }
        self[participant] = runtime
    }

    // MARK: - Active effects accessors

    public func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        runtime(for: combatant)?.activeEffects ?? []
    }

    public mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        mutateRuntime(for: combatant) { runtime in
            runtime.activeEffects = effects
        }
    }

    // MARK: - Health accessors

    public func health(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.currentHealth ?? 0
    }

    public func maxHealth(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.maxHealth ?? 0
    }

    // MARK: - Targeting

    /// The combatant the enemy prefers to attack: the living party member with
    /// the highest current health, preferring the hero when both are alive and tied.
    public var enemyAttackTarget: Combatant {
        if hero.isAlive && pet.isAlive {
            return hero.currentHealth >= pet.currentHealth ? hero.combatant : pet.combatant
        }
        if hero.isAlive { return hero.combatant }
        if pet.isAlive { return pet.combatant }
        return hero.combatant
    }

    public var isPartyDefeated: Bool {
        !hero.isAlive && !pet.isAlive
    }

    public var isEnemyDefeated: Bool {
        enemy.currentHealth == 0
    }

    /// True when `combatant` has any stun/freeze control meter at threshold,
    /// waiting to consume its next action opportunity.
    public func hasPendingActionSkip(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.effect.isActionSkipPending)
    }

    /// True when `combatant` has a full control meter for `keyword`, waiting
    /// to consume its next action opportunity.
    public func hasPendingActionSkip(for combatant: Combatant, keyword: Keyword) -> Bool {
        activeEffects(for: combatant).contains { activeEffect in
            activeEffect.keyword == keyword && activeEffect.effect.isActionSkipPending
        }
    }

    /// Mutates the runtime identified by `combatant` in place. A no-op
    /// when `combatant` is unknown.
    public mutating func mutateRuntime(for combatant: Combatant, _ body: (inout CombatantRuntime) -> Void) {
        guard let participant = participant(for: combatant) else { return }
        body(&self[participant])
    }

    public func hasConsumedDeathsDoor(for combatant: Combatant) -> Bool {
        runtime(for: combatant)?.hasConsumedDeathsDoor ?? false
    }

    public func isDeathsDoorActive(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains { $0.effect.kind == .deathsDoor }
    }
}
