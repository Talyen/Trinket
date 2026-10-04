import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HolyRewardSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `Holy restoration and defense rewards require a surviving wearer`(finallyDefeated: Bool) throws {
        var profile = CombatModifierProfile.zero
        for id in ["beacon", "sanctum", "absolving"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: finallyDefeated ? 1 : 20,
            companionHealth: 5,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.appendEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.thorns(8), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        _ = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .holy, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(battle.health(of: battle.hero) == (finallyDefeated ? 0 : 12))
        #expect(battle.health(of: battle.companion) == (finallyDefeated ? 5 : 6))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (finallyDefeated ? 0 : 1))
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .poison } == finallyDefeated)
    }
}
