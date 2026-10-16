import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

struct EquipmentLeechRegressionTests {
    @Test(arguments: [false, true])
    func `fractional attack Leech qualifies before defenses without inflating its healing fraction`(wounded: Bool) {
        var profile = CombatModifierProfile(modifiers: [.attackLeechPercent(0.1)])
        profile.triggers.leechAttackDamageVsBleedingMultiplier = 2
        profile.triggers.leechAttackBlockIgnorePercent = 0.5
        profile.triggers.leechIgnoresMitigation = true
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: wounded ? 10 : 20,
            heroModifiers: profile, enemyModifiers: CombatModifierProfile(damageTakenFlat: [.physical: 9]),
            appliesFightPacing: false,
        )
        battle.insertEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 1)
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let outcome = battle.resolveTestDamage(10, options: .attack(scaling: .flat, accuracy: .unavoidable))

        #expect(outcome.healthLost == 10)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 10)
        #expect(battle.health(of: battle.hero) == (wounded ? 11 : 20))
    }

    @Test func `fractional attack Leech qualifies Vitality Infusion at full Health`() {
        var profile = CombatantTalentCatalog.profile(for: ["panther_leech_t2_1"])
        profile.merge(.attackLeechPercent(0.1))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionModifiers: profile, appliesFightPacing: false,
        )

        let outcome = battle.resolveTestDamage(
            4, from: .companion, options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true),
        )

        #expect(outcome.healthLost == 8)
        #expect(battle.health(of: battle.companion) == battle.maxHealth(of: battle.companion))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 3)
    }
}
