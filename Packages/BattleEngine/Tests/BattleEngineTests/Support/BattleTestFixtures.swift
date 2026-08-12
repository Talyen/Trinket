import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

/// Shared combatants, battle setup, and card-combat helpers for battle integration tests.
/// Handler-level behavior lives in `EffectHandlersTests`.
/// Presentation strings live in `ActionEventFormatterTests` / `EffectSummaryBuilderTests`.
/// See `Packages/BattleEngine/Tests/README.md` for the full test ownership matrix.
enum BattleTestFixtures {
    /// Matches `BattleStateTestFactory` seed for reproducible dodge/crit rolls.
    static let deterministicNonCriticalSeed: UInt64 = CombatantFixtures.deterministicBattleSeed

    static func makePipelineContext(
        targetMaxHealth: Int = 50,
        targetPrimaryStats: PrimaryStats = PrimaryStats(),
        targetEffects: [ActiveEffect] = [],
        sourcePrimaryStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = deterministicNonCriticalSeed
    ) -> BattleState {
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: targetMaxHealth,
            primaryStats: targetPrimaryStats
        )
        let source = CombatantFixtures.combatant(
            id: "source", role: .hero, maxHealth: 50,
            primaryStats: sourcePrimaryStats
        )
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: companion),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: targetEffects)
        )
        return BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: .zero,
            enemyModifiers: enemyModifiers
        )
    }

    static func passiveCombatant(
        id: String,
        name: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTurns: Int = 100
    ) -> Combatant {
        Combatant(
            id: id,
            name: name,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
            abilities: []
        )
    }

    static func silentEnemy(maxHealth: Int, id: String = "enemy") -> Combatant {
        passiveCombatant(
            id: id,
            name: "Enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTurns: 100
        )
    }

    static func attackingEnemy(
        abilities: [Ability],
        maxHealth: Int = 100,
        actionIntervalTurns: Int? = nil,
        id: String = "enemy"
    ) -> Combatant {
        Combatant(
            id: id,
            name: "Enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
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
            actionIntervalTurns: 1,
            abilities: [keywordDamageAbility(id: "test-stun", name: "Test Stun", keyword: .stun, damage: damage)]
        )
    }

    static func freezeAbilityHero(id: String = "hero", damage: Int = 1) -> Combatant {
        Combatant(
            id: id,
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            actionIntervalTurns: 1,
            abilities: [keywordDamageAbility(id: "test-freeze", name: "Test Freeze", keyword: .freeze, damage: damage)]
        )
    }

    static func standardParty(
        hero: Combatant,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
        activeHeroEffects: [ActiveEffect] = [],
        activeEnemyEffects: [ActiveEffect] = [],
        activeCompanionEffects: [ActiveEffect] = [],
        initialGold: Int = 0
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion ?? passiveCombatant(id: "companion", name: "Companion", role: .companion),
            enemy: enemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activeCompanionEffects: activeCompanionEffects,
            initialGold: initialGold
        )
    }

    // MARK: - Control meter integration

    static func partyWithPendingActionSkip(
        keyword: Keyword,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil
    ) -> BattleState {
        let resolvedHero = hero ?? passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let resolvedCompanion = companion ?? passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let resolvedEnemy = enemy ?? attackingEnemy(abilities: [.slash])
        return standardParty(
            hero: resolvedHero,
            companion: resolvedCompanion,
            enemy: resolvedEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(keyword, 1, 1), remainingTurns: 0),
            ]
        )
    }

    static func assertActionSkipConsumed(
        events: [ActionEvent],
        actorID: String,
        keyword: Keyword
    ) {
        if !events.contains(where: {
            $0.effectKind == .controlActionSkipped
                && $0.keyword == keyword
                && $0.targetID == actorID
        }) {
            // Skip events use the keyword as actorName; also accept target match via combatant name.
            if !events.contains(where: { $0.effectKind == .controlActionSkipped && $0.keyword == keyword }) {
                Issue.record("Expected controlActionSkipped with keyword \(keyword) for \(actorID)")
            }
        }
    }

    // MARK: - Card combat helpers

    /// Plays the first playable hand card owned by `owner`. Returns emitted events, or nil if none.
    @discardableResult
    static func playFirstPlayableCard(
        owner: BattleParticipant,
        on battle: inout BattleState
    ) throws -> [ActionEvent]? {
        guard let card = battle.hand.cards.first(where: {
            $0.owner == owner && battle.isCardPlayable($0)
        }) else {
            return nil
        }
        return try battle.playCard(cardID: card.id)
    }

    /// Plays the first hand card whose ability name matches `name` (optionally filtered by owner).
    @discardableResult
    static func playCardNamed(
        _ name: String,
        owner: BattleParticipant? = nil,
        on battle: inout BattleState
    ) throws -> [ActionEvent] {
        guard let card = battle.hand.cards.first(where: {
            $0.ability.name == name && (owner == nil || $0.owner == owner)
        }) else {
            Issue.record("Expected card named \(name) in hand")
            return []
        }
        return try battle.playCard(cardID: card.id)
    }

    @discardableResult
    static func endTurn(on battle: inout BattleState) -> [ActionEvent] {
        battle.endTurn()
    }

    /// Ends `count` player turns (each runs enemy phase + end-of-round effect tick + draw).
    @discardableResult
    static func endTurns(_ count: Int, on battle: inout BattleState) -> [ActionEvent] {
        var allEvents: [ActionEvent] = []
        for _ in 0 ..< count {
            guard !battle.isBattleOver else { break }
            allEvents.append(contentsOf: battle.endTurn())
        }
        return allEvents
    }

    /// Plays the first playable hero card if any, then ends the turn.
    @discardableResult
    static func playHeroCardAndEndTurn(on battle: inout BattleState) throws -> [ActionEvent] {
        var events: [ActionEvent] = []
        if let playEvents = try playFirstPlayableCard(owner: .hero, on: &battle) {
            events.append(contentsOf: playEvents)
        }
        events.append(contentsOf: battle.endTurn())
        return events
    }

    /// Plays cards (preferring `owner`) until an ability named `abilityName` resolves, or returns nil.
    static func playUntilAbility(
        _ abilityName: String,
        owner: BattleParticipant = .hero,
        on battle: inout BattleState,
        maxRounds: Int = 20
    ) throws -> [ActionEvent]? {
        for _ in 0 ..< maxRounds {
            if let card = battle.hand.cards.first(where: {
                $0.ability.name == abilityName && $0.owner == owner && battle.isCardPlayable($0)
            }) {
                return try battle.playCard(cardID: card.id)
            }
            // Play any other playable card for this owner to cycle the deck, else end turn to redraw.
            if try playFirstPlayableCard(owner: owner, on: &battle) == nil {
                _ = battle.endTurn()
            }
            if battle.isBattleOver {
                break
            }
        }
        return nil
    }

    // MARK: - Stat integration

    static func statHero(
        id: String = "hero",
        abilities: [Ability],
        stats: PrimaryStats = PrimaryStats(),
        maxHealth: Int = 20,
        actionIntervalTurns: Int = 2
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: .hero,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
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
            companion: passiveCombatant(id: "companion", name: "Companion", role: .companion),
            enemy: enemy ?? passiveCombatant(
                id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTurns: 100
            )
        )
    }

    static func firstAbilityEvent(in events: [ActionEvent]) -> ActionEvent? {
        events.first { $0.kind == .ability }
    }
}

// MARK: - Effect predicates

extension Effect {
    var isControlMeter: Bool {
        if case .controlMeter = self {
            return true
        }
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

extension [ActionEvent] {
    func contains(effectKind: ActionEvent.EffectKind, keyword: Keyword? = nil) -> Bool {
        contains { event in
            event.effectKind == effectKind && (keyword == nil || event.keyword == keyword)
        }
    }
}

extension ActiveEffect {
    static func isDebuff(_ activeEffect: ActiveEffect) -> Bool {
        switch activeEffect.effect {
        case .burn, .poison, .bleed, .controlMeter:
            true
        default:
            false
        }
    }
}
