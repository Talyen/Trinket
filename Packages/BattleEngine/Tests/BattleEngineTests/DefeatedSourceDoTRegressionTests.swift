import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DefeatedSourceDoTRegressionTests {
    @Test(arguments: [Keyword.poison, .burn])
    func `Bleed converts damage after its source is defeated without granting personal rewards`(conversion: Keyword) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onBleedDamageNextBasicGuaranteedCrit = true
        profile.triggers.onBleedDamageNextBasicCritBonus = 0.35
        profile.triggers.onBleedDamageHealSelf = 2
        if conversion == .poison {
            profile.triggers.onBleedApplyPoison = 2
            profile.triggers.onBleedDealPoisonChancePercent = 1
        } else {
            profile.triggers.onBleedDealBurnDamage = 2
            profile.triggers.onBleedDealBurnChancePercent = 1
        }
        let bleed = ActiveEffect(id: 100, effect: .bleed(4), remainingTurns: 1, sourceActorID: "hero")
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            enemyEffects: [bleed], heroHealth: 0, heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        _ = EffectHandlers.handler(for: .bleed).advanceTurn(bleed, on: battle.enemy, in: &battle)

        #expect(battle.health(of: battle.enemy) == 94)
        #expect(CombatTriggerEngine.totalPotency(of: .poison, on: battle.enemy, in: battle) == (conversion == .poison ? 2 : 0))
        #expect(battle.health(of: battle.hero) == 0)
        #expect(!battle.roster.hero.talents.pending.basicGuaranteedCritical)
        #expect(battle.roster.hero.talents.pending.basicCriticalBonus == 0)
    }
}
