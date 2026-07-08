import Testing
import BattleEngine
import TrinketCore
import TrinketContent

/// Turn-scheduling and wiring contracts for stun/freeze control meters through
/// full battle ticks.
///
/// Pure meter math: `ControlMeterEngineTests`, `CombatPipelineTests`.
/// Threshold formulas: `PrimaryStatsRulesTests`.
/// Effect summaries: `EffectSummaryBuilderTests`.
/// Turn consumption primitives: `BattleTurnEngineTests`.
/// Full regression pin: `BattleGoldenPathTests.testStunThresholdGoldenPath`.
@Suite
struct ControlMeterIntegrationTests {
    @Test func actionSkipPreventsDamage() throws {
        for keyword in [Keyword.stun, Keyword.freeze] {
            var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
            let hero = battle.hero
            let events = BattleTestFixtures.advanceTicks(6, on: &battle)

            try #expect(battle.health(of: hero) == hero.maxHealth, "keyword=\(keyword)")
            try #expect(
                events.contains(effectKind: .controlActionSkipped, keyword: keyword),
                "keyword=\(keyword)"
            )
        }
    }

    @Test func actionSkipPersistsUntilActorsTurnThenConsumes() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        BattleTestFixtures.advanceTicks(5, on: &battle)
        try #expect(!(battle.activeEffects(of: enemy)).isEmpty)

        let step = battle.advanceOneStep()
        BattleTestFixtures.assertActionSkipConsumed(step: step, actorID: enemy.id, keyword: .stun)
    }

    @Test func actionSkipClaimsTurnWithoutAbilityEvent() throws {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        BattleTestFixtures.advanceTicks(5, on: &battle)

        let step = battle.advanceOneStep()
        if case let .acted(actor, events) = step {
            try #expect(actor.id == enemy.id)
            try #expect(events.contains { $0.effectKind == .controlActionSkipped })
            try #expect(!(events.contains { $0.kind == .ability }))
        } else {
            Issue.record("Expected stunned enemy to claim its step")
        }
    }

    @Test func stunDamageBuildsMeterTriggersAndSkipsNextAction() throws {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)

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
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)
        try #expect(battle.hasHeroEffect { effect in
            if case let .shield(.block, buffer, _) = effect, buffer > 0 { return true }
            return false
        })

        let events = BattleTestFixtures.advanceTicks(4, on: &battle)
        try #expect(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        try #expect(battle.health(of: battle.hero) == hero.maxHealth)
    }
}
