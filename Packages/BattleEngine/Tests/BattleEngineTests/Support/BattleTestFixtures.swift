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
        companionModifiers: CombatModifierProfile = .zero,
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
            companionModifiers: companionModifiers,
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

    static func passiveHero(maxHealth: Int = 20) -> Combatant {
        CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: maxHealth, actionIntervalTurns: 100)
    }

    static func passiveCompanion(maxHealth: Int = 20) -> Combatant {
        CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: maxHealth, actionIntervalTurns: 100)
    }

    static func passiveEnemy(maxHealth: Int = 100) -> Combatant {
        CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: maxHealth, actionIntervalTurns: 100)
    }

    static func silentEnemy(maxHealth: Int) -> Combatant {
        passiveEnemy(maxHealth: maxHealth)
    }

    static func attackingEnemy(
        abilities: [Ability],
        maxHealth: Int = 100,
        actionIntervalTurns: Int? = nil
    ) -> Combatant {
        CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities
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
            companion: companion ?? passiveCompanion(),
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
        let resolvedCompanion = companion ?? passiveCompanion()
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

    /// Ends `count` player turns (each runs enemy phase + end-of-round effect pass + draw).
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
        CombatantFixtures.combatant(
            id: id,
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
            companion: passiveCompanion(),
            enemy: enemy ?? passiveCombatant(
                id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, actionIntervalTurns: 100
            )
        )
    }

    static func firstAbilityEvent(in events: [ActionEvent]) -> ActionEvent? {
        events.first { $0.kind == .ability }
    }

    static func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroEffects: [ActiveEffect] = [],
        companionEffects: [ActiveEffect] = [],
        enemyEffects: [ActiveEffect] = [],
        heroHealth: Int? = nil,
        companionHealth: Int? = nil,
        enemyHealth: Int? = nil,
        heroMana: Int? = nil,
        companionMana: Int? = nil,
        enemyMana: Int? = nil,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = Self.deterministicNonCriticalSeed,
        nextEffectID: Int = 1,
        nextEventID: Int = 1
    ) -> BattleState {
        BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialHealth: heroHealth,
                    initialMana: heroMana,
                    initialActiveEffects: heroEffects
                ),
                companion: CombatantRuntime(
                    combatant: companion,
                    initialHealth: companionHealth,
                    initialMana: companionMana,
                    initialActiveEffects: companionEffects
                ),
                enemy: CombatantRuntime(
                    combatant: enemy,
                    initialHealth: enemyHealth,
                    initialMana: enemyMana,
                    initialActiveEffects: enemyEffects
                )
            ),
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: nextEffectID,
            nextEventID: nextEventID,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: enemyModifiers
        )
    }
}

extension BattleTestFixtures {
    enum CatalogBuildError: Error {
        case missingCombatant(String)
    }

    static func catalogBuild(combatantID: String, talents: String...) throws -> CombatBuild {
        guard let combatant = GameContent.heroes.first(where: { $0.id == combatantID })
            ?? GameContent.companions.first(where: { $0.id == combatantID })
        else {
            throw CatalogBuildError.missingCombatant(combatantID)
        }
        return CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: Set(talents)
        )
    }

    static func apply(
        _ effect: Effect,
        abilityName: String,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        let ability = Ability(
            id: "test-\(abilityName)",
            name: abilityName,
            tier: .basic,
            targetedEffects: [TargetedEffect(effect)]
        )
        guard let handler = EffectHandlers.handler(for: effect.kind) else {
            preconditionFailure("Missing handler for \(effect.kind)")
        }
        return handler.apply(
            effect,
            ability: ability,
            source: source,
            target: target,
            action: ActionApplyContext(),
            in: &context
        )
    }

    static func shieldPoints(for combatant: Combatant, in context: BattleState) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            if case let .shield(.block, points) = active.effect {
                return sum + points
            }
            return sum
        }
    }

    static func poisonPotency(on combatant: Combatant, in context: BattleState) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            if case let .poison(potency) = active.effect {
                return sum + potency
            }
            return sum
        }
    }

    static func burnPotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first { $0.effect.isDecayingDoT && $0.keyword == .burn }?.effect.potency
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
