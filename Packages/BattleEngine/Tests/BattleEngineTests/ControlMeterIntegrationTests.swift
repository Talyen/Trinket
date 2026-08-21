import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

/// Control-meter wiring through card combat endTurn / enemy skip.
///
/// Pure meter math: `ControlMeterEngineTests`, `CombatPipelineTests`.
/// Threshold formulas: `PrimaryStatsRulesTests`.
/// Effect summaries: `EffectSummaryBuilderTests`.
/// Turn consumption primitives: `BattleTurnEngineTests`.
struct ControlMeterIntegrationTests {
    @Test(arguments: [Keyword.stun, Keyword.freeze])
    func actionSkipPreventsDamage(keyword: Keyword) throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
        let hero = battle.hero
        let events = BattleTestFixtures.endTurn(on: &battle)

        try #expect(battle.health(of: hero) == hero.maxHealth, "keyword=\(keyword)")
        try #expect(
            events.contains(effectKind: .controlActionSkipped, keyword: keyword),
            "keyword=\(keyword)"
        )
    }

    @Test func actionSkipConsumesOnEnemyTurn() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        try #expect(!(battle.activeEffects(of: enemy)).isEmpty)

        let events = BattleTestFixtures.endTurn(on: &battle)
        BattleTestFixtures.assertActionSkipConsumed(events: events, actorID: enemy.id, keyword: .stun)
        try #expect(!(events.contains { $0.kind == .ability && $0.actorID == enemy.id }))
        // Skip is consumed, but Stunned status lingers into the next player turn.
        try #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(!(battle.roster.hasPendingActionSkip(for: enemy, keyword: .stun)))
    }

    @Test func stunStatusLingersThroughFollowingPlayerTurnWithoutSecondSkip() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy
        let hero = battle.hero

        let firstEnd = BattleTestFixtures.endTurn(on: &battle)
        BattleTestFixtures.assertActionSkipConsumed(events: firstEnd, actorID: enemy.id, keyword: .stun)
        try #expect(battle.roster.hasControlStatus(for: enemy, keyword: .stun))
        try #expect(CombatantBorderAccent.keyword(from: battle.activeEffects(of: enemy)) == .stun)
        try #expect(battle.health(of: hero) == hero.maxHealth)

        // Following player turn: status still active, no second skip queued.
        try #expect(!(battle.roster.hasPendingActionSkip(for: enemy)))

        let secondEnd = BattleTestFixtures.endTurn(on: &battle)
        try #expect(!(secondEnd.contains(effectKind: .controlActionSkipped, keyword: .stun)))
        try #expect(secondEnd.contains { $0.kind == .ability && $0.actorID == enemy.id })
        try #expect(!(battle.roster.hasControlStatus(for: enemy, keyword: .stun)))
        try #expect(battle.health(of: hero) < hero.maxHealth)
    }

    @Test func stunDamageBuildsMeterTriggersAndSkipsNextAction() throws {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTurns: 1,
            abilities: [CombatantFixtures.ability(id: "test-stun", name: "Test Stun", directDamage: 1, damageKeyword: .stun)]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        // Play stun cards until control triggers, then end turn so enemy skip resolves.
        var events: [ActionEvent] = []
        for _ in 0 ..< 8 {
            if let play = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &battle) {
                events.append(contentsOf: play)
            } else {
                break
            }
            if events.contains(effectKind: .controlTriggered, keyword: .stun) {
                break
            }
        }
        events.append(contentsOf: BattleTestFixtures.endTurn(on: &battle))

        try #expect(events.contains(effectKind: .controlTriggered, keyword: .stun))
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func shieldBashAppliesStunSkipAndBlock() throws {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5)
        var battle = BattleTestFixtures.standardParty(hero: hero, companion: companion, enemy: enemy)

        _ = try BattleTestFixtures.playCardNamed("Shield Bash", owner: .hero, on: &battle)
        try #expect(battle.hasHeroEffect { effect in
            if case let .shield(.block, buffer) = effect, buffer > 0 {
                return true
            }
            return false
        })

        let events = BattleTestFixtures.endTurn(on: &battle)
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }

    @Test func partyOwnerSkipBlocksCardPlayThenClearsOnEndTurn() throws {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.slash])
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTurns: 0),
            ]
        )

        // Re-bootstrap skip set after seeding effects via factory (init already ran).
        // Opening hand exists; hero should be marked skipping.
        battle.ownersSkippingThisPlayerTurn = [.hero]
        let heroCard = try #require(battle.hand.cards.first { $0.owner == .hero })
        try #expect(!battle.isCardPlayable(heroCard))

        do {
            _ = try battle.playCard(cardID: heroCard.id)
            Issue.record("Expected ownerSkipping error")
        } catch BattlePlayError.ownerSkipping {
            // expected
        }

        let events = BattleTestFixtures.endTurn(on: &battle)
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.ownersSkippingThisPlayerTurn.isEmpty)
        // Party skip is consumed once; the Stunned status drops so the hero does
        // not look CC'd while acting on the next turn.
        try #expect(!(battle.roster.hasControlStatus(for: battle.hero, keyword: .stun)))
        try #expect(!(battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .stun)))
        try #expect(battle.ownersSkippingThisPlayerTurn.isEmpty)
    }

    @Test func shatterAndDazedApplyDuringControlStatusLinger() throws {
        let jab = Ability(id: "jab", name: "Jab", tier: .basic, directDamage: 1, damageKeyword: .physical)
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [jab])
        let companion = BattleTestFixtures.passiveCombatant(id: "companion", name: "Companion", role: .companion)
        let enemy = BattleTestFixtures.silentEnemy(maxHealth: 100)

        var frozenBattle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.freeze, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetFrozenBonus: 2
                )
            ))
        )
        try #expect(!(frozenBattle.roster.hasPendingActionSkip(for: frozenBattle.enemy, keyword: .freeze)))
        try #expect(frozenBattle.roster.hasControlStatus(for: frozenBattle.enemy, keyword: .freeze))
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &frozenBattle)
        try #expect(100 - frozenBattle.health(of: frozenBattle.enemy) == 3)

        var stunnedBattle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.stun, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                damage: DamageTriggers(
                    damageWhileTargetStunnedBonus: 1
                )
            ))
        )
        try #expect(!(stunnedBattle.roster.hasPendingActionSkip(for: stunnedBattle.enemy, keyword: .stun)))
        try #expect(stunnedBattle.roster.hasControlStatus(for: stunnedBattle.enemy, keyword: .stun))
        _ = try BattleTestFixtures.playFirstPlayableCard(owner: .hero, on: &stunnedBattle)
        try #expect(100 - stunnedBattle.health(of: stunnedBattle.enemy) == 2)
    }
}
