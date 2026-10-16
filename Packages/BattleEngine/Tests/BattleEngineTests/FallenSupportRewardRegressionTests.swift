import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct FallenSupportRewardRegressionTests {
    @Test(arguments: [false, true])
    func `Sunwall requires a living Knight while committed Holy Thorns still deals damage`(survives: Bool) {
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t2_1", "knight_holy_t4_1"])
        profile.triggers.sunwallChancePercent = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: survives ? 2 : 1,
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.insertEffect(.thorns(4), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }

        #expect(battle.health(of: battle.hero) == (survives ? 1 : 0))
        #expect(battle.health(of: battle.enemy) == 96)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == (survives ? 4 : 0))
        #expect(outcome.events.contains { $0.abilityName == "Sunwall" } == survives)
    }

    @Test(arguments: [false, true])
    func `Toxic Transfusion requires its critical Companion to survive retaliation`(survives: Bool) {
        var hero = CombatantTalentCatalog.profile(for: ["ranger_poison_t4_1"])
        hero.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: survives ? 5 : 1,
            heroModifiers: hero, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.insertEffect(.thorns(4), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        _ = battle.resolveTestDamage(
            2,
            from: .companion,
            options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true),
        )

        #expect(battle.health(of: battle.companion) == (survives ? 1 : 0))
        #expect(battle.roster.hero.talents.pending.doubleNextPoisonAttack == survives)
        let poison = battle.resolveTestDamage(3, keyword: .poison, options: .attack(scaling: .flat, accuracy: .unavoidable))
        #expect(poison.healthLost == (survives ? 6 : 3))
    }
}
