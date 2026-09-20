import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HomesteadCombatTests {
    @Test(arguments: [false, true])
    func `crystal bonus changes only the existing critical hit`(critical: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 200),
            heroModifiers: .init(modifiers: [.criticalDamage(4)]),
        )
        battle.appliesFightPacing = false
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 10, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .effect(scaling: .items, abilityCriticalChanceBonus: critical ? 0 : -1, guaranteedCritical: critical),
        ))
        #expect(outcome.healthLost == (critical ? 24 : 10))
    }

    @Test func `leyline strengthens positive restoration without creating a zero grant`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(), heroModifiers: .init(modifiers: [.manaRestored(4)]),
        )
        _ = battle.payMana(1000, for: battle.hero)
        #expect(battle.restoreMana(0, to: battle.hero) == 0)
        #expect(battle.restoreMana(1, to: battle.hero) == min(5, battle.roster.maxMana(for: battle.hero)))
    }
}
