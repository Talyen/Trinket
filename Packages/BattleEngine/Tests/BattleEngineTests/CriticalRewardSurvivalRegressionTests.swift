import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CriticalRewardSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `Light Fingers rewards a Critical Hit only after its Rogue survives Thorns`(finallyDefeated: Bool) {
        let thorns = ActiveEffect(id: 100, effect: .thorns(8), remainingTurns: 0, sourceActorID: "enemy")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [thorns], heroHealth: 1,
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_gold_t1_1"]),
        )
        battle.appliesFightPacing = false
        battle.roster.hero.hasConsumedDeathsDoor = finallyDefeated

        let hit = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true),
        ))

        #expect(hit.healthLost == 8)
        #expect(battle.health(of: battle.enemy) == 92)
        #expect(battle.health(of: battle.hero) == (finallyDefeated ? 0 : 1))
        #expect(battle.gold == (finallyDefeated ? 0 : 2))
        #expect(hit.events.contains { $0.keyword == .gold && $0.amount == 2 } == !finallyDefeated)
    }
}
