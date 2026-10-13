import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsArithmeticBoundaryTests {
    @Test(arguments: [false, true])
    func `saturated Thorns accepts triggered gains and retaliates without overflowing`(talentGain: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockGainThornsPercent = 1
        profile.triggers.thornsDamageFlat = 1
        profile.triggers.thornsDamageDoubleWhileBlocked = true
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroEffects: [ActiveEffect(
                id: 1,
                effect: .thorns(Int.max),
                remainingTurns: 0,
            )],
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.enemy.hasConsumedDeathsDoor = true
        if talentGain {
            _ = CombatExecutor.run { await CombatTriggerEngine.heroTalentThorns(
                to: battle.hero, source: battle.hero, amount: 1, name: "Thorns", in: &battle,
            ) }
            DefensePoolEngine.set(2, on: battle.hero, in: &battle)
        } else {
            _ = battle.applyBlock(2, to: battle.hero, source: battle.hero, abilityName: "Block")
        }
        #expect(battle.activeEffects(of: battle.hero).first { $0.effect.kind == .thorns }?.effect.potency == Int.max)

        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(accuracy: .unavoidable))

        #expect(battle.isEnemyDefeated)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .thorns })
    }
}
