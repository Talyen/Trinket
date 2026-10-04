import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsResistanceRegressionTests {
    @Test(arguments: [Keyword.physical, .holy, .poison])
    func `Briar Ward resists actual Thorns including converted retaliation`(keyword: Keyword) {
        var hero = CombatModifierProfile.zero
        hero.triggers.thornsDealHoly = keyword == .holy
        hero.triggers.thornShedding = keyword == .poison
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: hero,
            enemyModifiers: .init(modifiers: [.damageTakenPercent(.thorns, 0.5)]),
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let hit = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(hit.events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 4 })
        let ordinary = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
        #expect(ordinary.healthLost == 8)
    }
}
