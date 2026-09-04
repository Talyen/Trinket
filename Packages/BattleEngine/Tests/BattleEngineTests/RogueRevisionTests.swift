import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
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

    @Test func `sap arrow grants gold against a stunned enemy`() throws {
        var battle = battleWithHandCard(
            .sapArrow,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.stun, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns,
                ),
            ],
        )
        _ = try BattleTestFixtures.playCardNamed("Sap Arrow", owner: .hero, on: &battle)
        try #expect(battle.gold == 2)
    }

    @Test func `sap arrow grants gold when it stuns the enemy itself`() throws {
        var battle = battleWithHandCard(.sapArrow, enemyMaxHealth: 10)
        _ = try BattleTestFixtures.playCardNamed("Sap Arrow", owner: .hero, on: &battle)
        try #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        try #expect(battle.gold == 2)
    }

    @Test func `sap arrow grants no gold when the enemy stays unstunned`() throws {
        var battle = battleWithHandCard(.sapArrow)
        _ = try BattleTestFixtures.playCardNamed("Sap Arrow", owner: .hero, on: &battle)
        try #expect(!(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun)))
        try #expect(battle.gold == 0)
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

    @Test func `scent of blood rewards bleeding and low health separately`() throws {
        let profile = CombatantTalentCatalog.profile(for: ["rogue_bleed_t3_2"])
        try #expect(profile.triggers.damageVsBleedingBonus == 1)
        try #expect(profile.triggers.damageBelowHealthPercentThreshold == 0.5)
        try #expect(profile.triggers.damageBelowHealthPercentBonus == 1)

        func dealt(targetMaxHealth: Int, targetHealth: Int?, targetEffects: [ActiveEffect]) -> Int {
            var battle = BattleStateTestFactory.makeMinimalBattle(
                hero: CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50),
                companion: CombatantFixtures.combatant(id: "companion", role: .companion),
                enemy: CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: targetMaxHealth),
                enemyEffects: targetEffects,
                enemyHealth: targetHealth,
                heroModifiers: profile,
            )
            let outcome = battle.resolveDamage(
                DamageRequest(amount: 4, target: battle.roster.enemy.combatant, keyword: .physical, sourceActorID: "source"),
            )
            return outcome.healthLost
        }

        #expect(dealt(targetMaxHealth: 50, targetHealth: nil, targetEffects: []) == 4)
        #expect(dealt(
            targetMaxHealth: 50,
            targetHealth: nil,
            targetEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
        ) == 5)
        #expect(dealt(targetMaxHealth: 50, targetHealth: 20, targetEffects: []) == 5)
        #expect(dealt(
            targetMaxHealth: 50,
            targetHealth: 20,
            targetEffects: [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 0)],
        ) == 6)
    }
}
