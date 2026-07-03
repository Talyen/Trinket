import XCTest
import BattleEngine
import TrinketCore
import TrinketContent


/// Shared combatants, battle setup, and tick helpers for battle integration tests.
/// Handler-level behavior lives in `EffectHandlersTests`.
/// Presentation strings live in `ActionEventFormatterTests` / `EffectSummaryBuilderTests`.
enum BattleTestFixtures {
    static func passiveCombatant(
        id: String,
        name: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int = 100
    ) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: []
        )
    }

    static func silentEnemy(maxHealth: Int, id: String = "enemy") -> Combatant {
        passiveCombatant(
            id: id,
            name: "Enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTicks: 100
        )
    }

    static func attackingEnemy(
        abilities: [Ability],
        maxHealth: Int = 100,
        actionIntervalTicks: Int? = nil,
        id: String = "enemy"
    ) -> Combatant {
        Combatant(
            id: id,
            name: "Enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: abilities
        )
    }

    static func keywordDamageAbility(
        id: String,
        name: String,
        keyword: Keyword,
        damage: Int
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            tier: .basic,
            directDamage: damage,
            damageKeyword: keyword,
            description: "Deal \(damage) \(keyword.rawValue) damage."
        )
    }

    static func stunAbilityHero(id: String = "hero", damage: Int = 1) -> Combatant {
        Combatant(
            id: id,
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [keywordDamageAbility(id: "test-stun", name: "Test Stun", keyword: .stun, damage: damage)]
        )
    }

    static func freezeAbilityHero(id: String = "hero", damage: Int = 1) -> Combatant {
        Combatant(
            id: id,
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTicks: 1,
            abilities: [keywordDamageAbility(id: "test-freeze", name: "Test Freeze", keyword: .freeze, damage: damage)]
        )
    }

    static func standardParty(
        hero: Combatant,
        pet: Combatant? = nil,
        enemy: Combatant? = nil,
        activeHeroEffects: [ActiveEffect] = [],
        activeEnemyEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet ?? passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: enemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activePetEffects: activePetEffects,
            initialGold: initialGold
        )
    }

    /// Advances `count` ticks and returns every event emitted along the way.
    @discardableResult
    static func advanceTicks(_ count: Int, on battle: inout BattleState) -> [ActionEvent] {
        var allEvents: [ActionEvent] = []
        for _ in 0 ..< count {
            allEvents.append(contentsOf: battle.advanceOneStep().events)
        }
        return allEvents
    }

    /// Advances until `actorName` uses `abilityName`, or returns nil after `maxSteps`.
    static func advanceUntilAbility(
        _ abilityName: String,
        actor actorName: String = "Hero",
        on battle: inout BattleState,
        maxSteps: Int = 40
    ) -> BattleStep? {
        for _ in 0 ..< maxSteps {
            let step = battle.advanceOneStep()
            if step.events.contains(where: { $0.abilityName == abilityName && $0.actorName == actorName }) {
                return step
            }
            if battle.isBattleOver { break }
        }
        return nil
    }

    // MARK: - Stat integration

    static func statHero(
        id: String = "hero",
        abilities: [Ability],
        stats: PrimaryStats = PrimaryStats(),
        maxHealth: Int = 20,
        actionIntervalTicks: Int = 2
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: .hero,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: abilities,
            primaryStats: stats
        )
    }

    static func statBattle(
        hero: Combatant,
        enemy: Combatant? = nil
    ) -> BattleState {
        standardParty(
            hero: hero,
            pet: passiveCombatant(id: "pet", name: "Pet", role: .pet),
            enemy: enemy ?? passiveCombatant(
                id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTicks: 100
            )
        )
    }

    static func advanceUntilActorActs(
        _ actorID: String,
        on battle: inout BattleState,
        maxSteps: Int = 20
    ) -> BattleStep? {
        for _ in 0 ..< maxSteps {
            let step = battle.advanceOneStep()
            if case let .acted(actor, _) = step, actor.id == actorID {
                return step
            }
            if battle.isBattleOver { break }
        }
        return nil
    }

    static func firstAbilityEvent(in step: BattleStep) -> ActionEvent? {
        step.events.first { $0.kind == .ability }
    }
}

// MARK: - Effect predicates

extension Effect {
    var preventionBuildupValues: (Keyword, Int, Int)? {
        if case let .preventionBuildup(keyword, amount, threshold) = self {
            return (keyword, amount, threshold)
        }
        return nil
    }

    var isPrevention: Bool {
        if case .prevention = self { return true }
        return false
    }

    var isPreventionBuildup: Bool {
        if case .preventionBuildup = self { return true }
        return false
    }
}

extension BattleState {
    func hasHeroEffect(matching predicate: (Effect) -> Bool) -> Bool {
        activeEffects(of: hero).contains { predicate($0.effect) }
    }

    func hasEnemyEffect(matching predicate: (Effect) -> Bool) -> Bool {
        activeEffects(of: enemy).contains { predicate($0.effect) }
    }

    func firstEnemyEffect(matching predicate: (Effect) -> Bool) -> ActiveEffect? {
        activeEffects(of: enemy).first { predicate($0.effect) }
    }
}

extension Array where Element == ActionEvent {
    func contains(effectKind: ActionEvent.EffectKind, keyword: Keyword? = nil) -> Bool {
        contains { event in
            event.effectKind == effectKind && (keyword == nil || event.keyword == keyword)
        }
    }
}

extension ActiveEffect {
    static func isDebuff(_ activeEffect: ActiveEffect) -> Bool {
        switch activeEffect.effect {
        case .burn, .poison, .bleed, .prevention:
            return true
        default:
            return false
        }
    }
}
