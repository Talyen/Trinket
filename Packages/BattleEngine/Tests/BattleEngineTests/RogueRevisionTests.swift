import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct RogueRevisionTests {
    private func battleWithHandCard(
        _ ability: Ability,
        enemyMaxHealth: Int = 100,
        activeEnemyEffects: [ActiveEffect] = [],
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [ability],
            enemyMaxHealth: enemyMaxHealth,
            heroModifiers: heroModifiers,
        )
        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: ability, owner: .hero)])
        if !activeEnemyEffects.isEmpty {
            BattleStateTestFactory.seedActiveEffects(activeEnemyEffects, for: battle.enemy, on: &battle)
        }
        return battle
    }

    @Test func `coinmail converts combat gold into block`() throws {
        let coinmail = try #require(CombatantTalentCatalog.effect(for: "rogue_gold_t1_2"))
        try #expect(coinmail.name == "Coinmail")
        let profile = CombatantTalentCatalog.profile(for: ["rogue_gold_t1_2"])
        try #expect(profile.triggers.goldGainBlockPercent == 0.5)
        var battle = battleWithHandCard(.steal, heroModifiers: profile)
        _ = try BattleTestFixtures.playCardNamed("Steal", owner: .hero, on: &battle)
        try #expect(battle.gold == 2)
        try #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 1)
    }

    @Test func `mortal wound halves healing received by bleeding enemies`() {
        let profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t3_2"])
        #expect(profile.triggers.bleedingEnemyHealingMultiplier == 0.5)
        for bleeding in [false, true] {
            let effects = bleeding ? [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)] : []
            var battle = BattleTestFixtures.makePipelineContext(targetEffects: effects, heroModifiers: profile)
            battle.appliesFightPacing = false
            battle.roster.enemy.currentHealth = 10
            _ = battle.healEmitting(amount: 8, target: battle.enemy, source: battle.enemy, abilityName: "Heal")
            #expect(battle.roster.enemy.currentHealth == (bleeding ? 14 : 18))
        }
    }
}
