import Foundation
import TrinketCore
import TrinketContent

public enum BattleParticipant: CaseIterable {
    case hero
    case pet
    case enemy
}

/// Collection of the three `CombatantRuntime`s participating in a battle:
/// the hero, the pet, and the enemy. Provides dispatch by role or by
/// `Combatant` identity, plus the ready-actor picker used by the turn loop.
///
/// The roster is the single source of truth for per-combatant mutable state
/// (health, active effects, action schedules, action counts). `BattleState`
/// delegates to it.
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
        if combatant.id == hero.id { return .hero }
        if combatant.id == pet.id { return .pet }
        if combatant.id == enemy.id { return .enemy }
        return nil
    }

    // MARK: - Dispatch by Combatant identity

    /// Returns the runtime whose `id` matches `combatant.id`, if any.
    public func runtime(for combatant: Combatant) -> CombatantRuntime? {
        if combatant.id == hero.id { return hero }
        if combatant.id == pet.id { return pet }
        if combatant.id == enemy.id { return enemy }
        return nil
    }

    /// Returns the runtime with the given `id`, if any.
    public func combatant(for id: String) -> CombatantRuntime? {
        if id == hero.id { return hero }
        if id == pet.id { return pet }
        if id == enemy.id { return enemy }
        return nil
    }

    /// Replaces the runtime whose `id` matches `runtime.id`.
    public mutating func update(_ runtime: CombatantRuntime) {
        if runtime.id == hero.id { hero = runtime }
        else if runtime.id == pet.id { pet = runtime }
        else if runtime.id == enemy.id { enemy = runtime }
    }

    // MARK: - Active effects accessors

    public func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        runtime(for: combatant)?.activeEffects ?? []
    }

    public mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        if combatant.id == hero.id { hero.activeEffects = effects }
        else if combatant.id == pet.id { pet.activeEffects = effects }
        else { enemy.activeEffects = effects }
    }

    // MARK: - Health accessors

    public func health(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.currentHealth ?? 0
    }

    public func maxHealth(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.maxHealth ?? 0
    }

    // MARK: - Ready-actor picker

    /// Returns the runtimes that are eligible to act on `tick`, sorted by
    /// `(nextReadyAtTick ascending, effectiveInterval descending, roleOrder
    /// ascending)`. The role-order tiebreaker preserves the historical
    /// hero < pet < enemy ordering used by the turn loop.
    public func readyCombatants(atTick tick: Int) -> [CombatantRuntime] {
        let ordered: [(runtime: CombatantRuntime, roleOrder: Int)] = [
            (hero, 0),
            (pet, 1),
            (enemy, 2)
        ]
        return ordered
            .filter { $0.runtime.isReady(atTick: tick) }
            .sorted { lhs, rhs in
                if lhs.runtime.nextReadyAtTick != rhs.runtime.nextReadyAtTick {
                    return lhs.runtime.nextReadyAtTick < rhs.runtime.nextReadyAtTick
                }
                if lhs.runtime.actionSpeed.effectiveInterval != rhs.runtime.actionSpeed.effectiveInterval {
                    return lhs.runtime.actionSpeed.effectiveInterval > rhs.runtime.actionSpeed.effectiveInterval
                }
                return lhs.roleOrder < rhs.roleOrder
            }
            .map(\.runtime)
    }

    // MARK: - Targeting

    /// The combatant the enemy prefers to attack: prefers the hero when both
    /// are alive, otherwise the one with higher health.
    public var enemyAttackTarget: Combatant {
        if !hero.isAlive { return pet.combatant }
        if !pet.isAlive { return hero.combatant }
        return hero.currentHealth >= pet.currentHealth ? hero.combatant : pet.combatant
    }

    public var isPartyDefeated: Bool {
        !hero.isAlive && !pet.isAlive
    }

    public var isEnemyDefeated: Bool {
        enemy.currentHealth == 0
    }

    /// True when `combatant` has an active `.prevention` effect with
    /// `remainingTicks > 0`.
    public func hasActivePrevention(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: {
            if case .prevention = $0.effect, $0.remainingTicks > 0 { return true }
            return false
        })
    }

    /// Mutates the runtime identified by `combatant` in place. A no-op
    /// when `combatant` is unknown.
    public mutating func mutateRuntime(for combatant: Combatant, _ body: (inout CombatantRuntime) -> Void) {
        if combatant.id == hero.id { body(&hero) }
        else if combatant.id == pet.id { body(&pet) }
        else if combatant.id == enemy.id { body(&enemy) }
    }
}
