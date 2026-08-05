import Foundation
import TrinketContent
import TrinketCore

public enum BattleParticipant: CaseIterable, Sendable {
    case hero
    case companion
    case enemy

    /// Participants in effect-tick order for each end-of-round pass.
    public static let effectTurnOrder: [Self] = [.enemy, .hero, .companion]

    public var isPartyMember: Bool {
        switch self {
        case .hero, .companion: true
        case .enemy: false
        }
    }
}

/// Collection of the three `CombatantRuntime`s participating in a battle:
/// the hero, the companion, and the enemy. Provides dispatch by role or by
/// `Combatant` identity.
///
/// The roster is the single source of truth for per-combatant mutable state
/// (health, active effects, action counts). `BattleState` delegates to it.
public struct BattleRoster {
    public var hero: CombatantRuntime
    public var companion: CombatantRuntime
    public var enemy: CombatantRuntime

    public init(hero: CombatantRuntime, companion: CombatantRuntime, enemy: CombatantRuntime) {
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
    }

    /// All three runtimes, in role order (hero, companion, enemy).
    public var allRuntimes: [CombatantRuntime] {
        [hero, companion, enemy]
    }

    public subscript(participant: BattleParticipant) -> CombatantRuntime {
        get {
            switch participant {
            case .hero: hero
            case .companion: companion
            case .enemy: enemy
            }
        }
        set {
            switch participant {
            case .hero: hero = newValue
            case .companion: companion = newValue
            case .enemy: enemy = newValue
            }
        }
    }

    public func participant(for combatant: Combatant) -> BattleParticipant? {
        switch combatant.role {
        case .hero: .hero
        case .companion: .companion
        case .enemy: .enemy
        }
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
        if hero.isAlive, companion.isAlive {
            return hero.currentHealth >= companion.currentHealth ? hero.combatant : companion.combatant
        }
        if hero.isAlive {
            return hero.combatant
        }
        if companion.isAlive {
            return companion.combatant
        }
        return hero.combatant
    }

    public var isPartyDefeated: Bool {
        !hero.isAlive && !companion.isAlive
    }

    public var isEnemyDefeated: Bool {
        enemy.currentHealth == 0
    }

    /// True when `combatant` has any stun/freeze meter still awaiting an
    /// unconsumed action skip.
    public func hasPendingActionSkip(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.isAwaitingActionSkip)
    }

    /// True when `combatant` has a full control meter for `keyword` still
    /// awaiting an unconsumed action skip.
    public func hasPendingActionSkip(for combatant: Combatant, keyword: Keyword) -> Bool {
        activeEffects(for: combatant).contains { activeEffect in
            activeEffect.keyword == keyword && activeEffect.isAwaitingActionSkip
        }
    }

    /// True when `combatant` has a full stun/freeze meter (status active),
    /// whether or not the action skip has already been consumed.
    public func hasControlStatus(for combatant: Combatant, keyword: Keyword) -> Bool {
        activeEffects(for: combatant).contains { activeEffect in
            activeEffect.keyword == keyword && activeEffect.effect.isActionSkipPending
        }
    }

    /// True when `combatant` has any full stun/freeze meter (status active).
    public func hasControlStatus(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.effect.isActionSkipPending)
    }

    /// Removes full stun/freeze meters that are no longer awaiting a skip
    /// (post-consume linger), so the combatant does not look CC'd while acting.
    public mutating func clearControlStatusLinger(for combatant: Combatant) {
        let updated = activeEffects(for: combatant).filter { activeEffect in
            !(activeEffect.effect.isActionSkipPending && !activeEffect.isAwaitingActionSkip)
        }
        setActiveEffects(updated, for: combatant)
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
