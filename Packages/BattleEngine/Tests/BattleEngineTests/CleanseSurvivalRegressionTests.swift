import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CleanseSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `cleanse retains its removal but requires a surviving caster for later rewards`(survives: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleanseHolyDamage = 3
        profile.triggers.cleanseSelfHeal = 2
        profile.triggers.cleansePartyBlock = 3
        profile.triggers.cleanseAffectsBothHeroAndCompanion = true
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 5, companionHealth: survives ? 20 : 1,
            companionModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.appendEffect(.poison(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.burn(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let outcome = battle.recordingResult { battle in await EffectRemovalOperation.resolveCleanse(
            .all(nil), source: battle.companion, target: battle.companion, abilityName: "Cleanse",
            baseHeal: 6, healTarget: .lowestHealthAlly, in: &battle,
        ) }

        #expect(battle.roster.companion.isAlive == survives)
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.isRemovableDebuff })
        #expect(outcome.events.contains { $0.effectKind == .cleanseApplied && $0.targetID == battle.companion.id })
        #expect(battle.hasTalentDebuff(on: battle.hero) == !survives)
        #expect((battle.health(of: battle.hero) > 5) == survives)
        #expect((DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) > 0) == survives)
    }
}
