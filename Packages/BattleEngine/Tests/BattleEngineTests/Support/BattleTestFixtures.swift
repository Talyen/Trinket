import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

enum BattleTestFixtures {
    static func makeAffixBattle(
        heroHealth: Int? = nil,
        heroEffects: [ActiveEffect] = [],
        enemyEffects: [ActiveEffect] = [],
        modifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: heroEffects,
            enemyEffects: enemyEffects,
            heroHealth: heroHealth,
            heroModifiers: modifiers, appliesFightPacing: false,
        )
    }

    static func thorns(on combatant: Combatant, in battle: BattleState) -> Int {
        battle.roster.activeEffects(for: combatant).reduce(0) { total, active in
            if case let .thorns(amount) = active.effect {
                return total + amount
            }
            return total
        }
    }

    static func makePipelineContext(
        targetMaxHealth: Int = 50,
        targetEffects: [ActiveEffect] = [],
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = CombatantFixtures.deterministicBattleSeed,
        appliesFightPacing: Bool = true,
    ) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: targetMaxHealth),
            enemyEffects: targetEffects,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: enemyModifiers,
            rngSeed: seed,
            appliesFightPacing: appliesFightPacing,
        )
    }

    static func attackingEnemy(
        abilities: [Ability],
        maxHealth: Int = 100,
        actionIntervalTurns: Int? = nil,
    ) -> Combatant {
        CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            maxHealth: maxHealth,
            actionIntervalTurns: actionIntervalTurns,
            abilities: abilities,
        )
    }

    static func partyWithPendingActionSkip(
        keyword: Keyword,
        hero: Combatant? = nil,
        companion: Combatant? = nil,
        enemy: Combatant? = nil,
    ) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy ?? attackingEnemy(abilities: [.slash]),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(keyword, 1, 1), remainingTurns: 0),
            ],
        )
    }

    @discardableResult
    static func playFirstPlayableCard(
        owner: BattleParticipant,
        on battle: inout BattleState,
    ) throws -> [ActionEvent]? {
        guard let card = battle.hand.cards.first(where: {
            $0.owner == owner && battle.isCardPlayable($0)
        }) else {
            return nil
        }
        return try battle.playCard(cardID: card.id).events
    }

    @discardableResult
    static func playCardNamed(
        _ name: String,
        owner: BattleParticipant? = nil,
        on battle: inout BattleState,
    ) throws -> [ActionEvent] {
        guard let card = battle.hand.cards.first(where: {
            $0.ability.name == name && (owner == nil || $0.owner == owner)
        }) else {
            Issue.record("Expected card named \(name) in hand")
            return []
        }
        return try battle.playCard(cardID: card.id).events
    }
}

extension BattleTestFixtures {
    enum CatalogBuildError: Error {
        case missingCombatant(String)
    }

    static func catalogBuild(combatantID: String, talents: String...) throws -> CombatBuild {
        guard let combatant = GameContent.combatant(matching: combatantID) else {
            throw CatalogBuildError.missingCombatant(combatantID)
        }
        return CombatBuildResolver.build(
            combatant: combatant,
            equipmentLoadout: EquipmentLoadout(),
            inventory: [],
            unlockedTalents: Set(talents),
        )
    }

    /// Find a branch with cheap RNG-only resolution, then execute the battle once.
    static func rngSelectingOutcome(
        _ ability: Ability,
        in battle: BattleState,
        actor: BattleParticipant = .hero,
        matching matches: (Ability) -> Bool,
    ) throws -> SeededRandomNumberGenerator {
        let outcomes = BattleAbilityRules.possibleOutcomes(
            ability, action: BattleActionContext(actor: battle.roster[actor].combatant, in: battle), in: battle,
        )
        let seed = try #require((UInt64(1) ... 192).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return matches(outcomes.resolve(using: &rng))
        })
        return SeededRandomNumberGenerator(seed: seed)
    }

    static func shieldPoints(for combatant: Combatant, in context: BattleState) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            if case let .shield(.block, points) = active.effect {
                return sum + points
            }
            return sum
        }
    }

    static func burnPotency(on battle: BattleState) -> Int? {
        battle.activeEffects(of: battle.enemy).first { $0.effect.isDecayingDoT && $0.keyword == .burn }?.effect.potency
    }
}

extension [ActionEvent] {
    func contains(effectKind: ActionEvent.EffectOutcome, keyword: Keyword? = nil) -> Bool {
        contains { event in
            event.effectKind == effectKind && (keyword == nil || event.keyword == keyword)
        }
    }
}

extension CombatModifierProfile {
    static func withTriggers(_ configure: (inout CombatTraitTriggers.Fields) -> Void) -> Self {
        Self(triggers: .init(configure))
    }
}
