import BattleEngine
import Testing
import TrinketContent
import TrinketCore

/// Control-meter wiring through card combat endTurn / enemy skip.
///
/// Pure meter math: `ControlMeterEngineTests`, `CombatPipelineTests`.
/// Threshold formulas: `PrimaryStatsRulesTests`.
/// Effect summaries: `EffectSummaryBuilderTests`.
/// Turn consumption primitives: `BattleTurnEngineTests`.
struct ControlMeterIntegrationTests {
    @Test func actionSkipPreventsDamage() throws {
        for keyword in [Keyword.stun, Keyword.freeze] {
            var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
            let hero = battle.hero
            let events = BattleTestFixtures.endTurn(on: &battle)

            try #expect(battle.health(of: hero) == hero.maxHealth, "keyword=\(keyword)")
            try #expect(
                events.contains(effectKind: .controlActionSkipped, keyword: keyword),
                "keyword=\(keyword)"
            )
        }
    }

    @Test func actionSkipConsumesOnEnemyTurn() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        try #expect(!(battle.activeEffects(of: enemy)).isEmpty)

        let events = BattleTestFixtures.endTurn(on: &battle)
        BattleTestFixtures.assertActionSkipConsumed(events: events, actorID: enemy.id, keyword: .stun)
        try #expect(!(events.contains { $0.kind == .ability && $0.actorID == enemy.id }))
    }

    @Test func stunDamageBuildsMeterTriggersAndSkipsNextAction() throws {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
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
                ActiveEffect(id: 1, effect: .controlMeter(.stun, 1, 1), remainingTurns: 0)
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
    }
}
