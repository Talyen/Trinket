import Foundation
import TrinketCore
import TrinketContent

public enum BattleParticipant: CaseIterable, Sendable {
    case hero
    case pet
    case enemy

    /// Participants in effect-tick order for each global battle step.
    public static let effectTickOrder: [BattleParticipant] = [.enemy, .hero, .pet]

    /// Tiebreaker for ready-actor selection when schedule and interval tie:
    /// hero (0) < pet (1) < enemy (2).
    public var turnPriority: Int {
        switch self {
        case .hero: return 0
        case .pet: return 1
        case .enemy: return 2
        }
    }
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
        BattleParticipant.allCases.first { self[$0].id == combatant.id }
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
        guard let participant = participant(for: combatant) else { return }
        self[participant].activeEffects = effects
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
    /// `(nextReadyAtTick ascending, effectiveInterval descending, turnPriority
    /// ascending)`. `turnPriority` uses `BattleParticipant.turnPriority`
    /// (hero < pet < enemy).
    public func readyCombatants(atTick tick: Int) -> [CombatantRuntime] {
        BattleParticipant.allCases
            .map { (runtime: self[$0], turnPriority: $0.turnPriority) }
            .filter { $0.runtime.isReady(atTick: tick) }
            .sorted { lhs, rhs in
                if lhs.runtime.nextReadyAtTick != rhs.runtime.nextReadyAtTick {
                    return lhs.runtime.nextReadyAtTick < rhs.runtime.nextReadyAtTick
                }
                if lhs.runtime.actionSpeed.effectiveInterval != rhs.runtime.actionSpeed.effectiveInterval {
                    return lhs.runtime.actionSpeed.effectiveInterval > rhs.runtime.actionSpeed.effectiveInterval
                }
                return lhs.turnPriority < rhs.turnPriority
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

    /// True when `combatant` has stun/freeze buildup at threshold, waiting to
    /// consume its next scheduled action.
    public func hasPendingStunFreezeSkip(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.effect.isTriggeredPreventionBuildup)
    }

    /// Mutates the runtime identified by `combatant` in place. A no-op
    /// when `combatant` is unknown.
    public mutating func mutateRuntime(for combatant: Combatant, _ body: (inout CombatantRuntime) -> Void) {
        guard let participant = participant(for: combatant) else { return }
        body(&self[participant])
    }
}
