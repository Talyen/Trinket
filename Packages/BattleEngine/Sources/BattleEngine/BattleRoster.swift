import Foundation
import TrinketContent
import TrinketCore

public enum BattleParticipant: CaseIterable, Sendable {
    case hero
    case companion
    case enemy

    public static let effectTurnOrder: [Self] = [.enemy, .hero, .companion]

    public var isPartyMember: Bool {
        switch self {
        case .hero, .companion: true
        case .enemy: false
        }
    }
}

public struct BattleRoster {
    public package(set) var hero: CombatantRuntime
    public package(set) var companion: CombatantRuntime
    public package(set) var enemy: CombatantRuntime

    public init(hero: CombatantRuntime, companion: CombatantRuntime, enemy: CombatantRuntime) {
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
    }

    public package(set) subscript(participant: BattleParticipant) -> CombatantRuntime {
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

    public func runtime(for combatant: Combatant) -> CombatantRuntime? {
        participant(for: combatant).map { self[$0] }
    }

    public func combatant(for id: String) -> CombatantRuntime? {
        if hero.id == id {
            return hero
        }
        if companion.id == id {
            return companion
        }
        if enemy.id == id {
            return enemy
        }
        return nil
    }

    package mutating func update(_ runtime: CombatantRuntime) {
        guard let participant = participant(for: runtime.combatant) else { return }
        self[participant] = runtime
    }

    public func activeEffects(for combatant: Combatant) -> [ActiveEffect] {
        runtime(for: combatant)?.activeEffects ?? []
    }

    package mutating func setActiveEffects(_ effects: [ActiveEffect], for combatant: Combatant) {
        mutateRuntime(for: combatant) { runtime in
            runtime.activeEffects = effects
        }
    }

    public func health(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.currentHealth ?? 0
    }

    public func maxHealth(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.maxHealth ?? 0
    }

    public func maxMana(for combatant: Combatant) -> Int {
        runtime(for: combatant)?.maxMana ?? 0
    }

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

    public func hasPendingActionSkip(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.isAwaitingActionSkip)
    }

    public func hasPendingActionSkip(for combatant: Combatant, keyword: Keyword) -> Bool {
        activeEffects(for: combatant).contains { activeEffect in
            activeEffect.keyword == keyword && activeEffect.isAwaitingActionSkip
        }
    }

    public func hasControlStatus(for combatant: Combatant, keyword: Keyword) -> Bool {
        activeEffects(for: combatant).contains { activeEffect in
            activeEffect.keyword == keyword && activeEffect.effect.isActionSkipPending
        }
    }

    func hasAffliction(_ keyword: Keyword, on combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains { active in
            guard active.effect.keyword == keyword else { return false }
            switch active.effect {
            case let .bleed(potency):
                return potency > 0 && active.remainingTurns > 0
            case let .burn(potency), let .poison(potency):
                return potency > 0
            default:
                return active.effect.isRemovableDebuff
            }
        }
    }

    public func hasControlStatus(for combatant: Combatant) -> Bool {
        activeEffects(for: combatant).contains(where: \.effect.isActionSkipPending)
    }

    package mutating func clearControlStatusLinger(for combatant: Combatant) {
        let updated = activeEffects(for: combatant).filter { activeEffect in
            !(activeEffect.effect.isActionSkipPending && !activeEffect.isAwaitingActionSkip)
        }
        setActiveEffects(updated, for: combatant)
    }

    package mutating func mutateRuntime(for combatant: Combatant, _ body: (inout CombatantRuntime) -> Void) {
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
