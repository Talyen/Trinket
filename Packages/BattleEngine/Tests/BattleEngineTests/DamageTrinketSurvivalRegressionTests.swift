import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DamageTrinketSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `Blood Money grants Gold from lingering Bleed only while its wearer lives`(wearerDefeated: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "cutpurse_knife"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: wearerDefeated ? 0 : 20,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.bleed(4), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        _ = CombatExecutor.run { await EffectTurnEngine.advanceEffects(on: battle.enemy, context: &battle) }

        #expect(battle.roster.enemy.currentHealth == 96)
        #expect(battle.gold == (wearerDefeated ? 0 : 1))
    }

    @Test(arguments: [false, true])
    func `Martial Guard rewards committed Thorns only after its wearer survives the incoming hit`(
        finallyDefeated: Bool,
    ) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "vanguards_crest"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.hasConsumedDeathsDoor = finallyDefeated
        battle.appendEffect(.thorns(8), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 0)

        let outcome = battle.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )

        #expect(battle.roster.enemy.currentHealth == 92)
        #expect(battle.roster.hero.currentHealth == (finallyDefeated ? 0 : 1))
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == (finallyDefeated ? 0 : 4))
        #expect(outcome.events.contains {
            $0.abilityName == "Martial Guard" && $0.effectKind == .shieldApplied && $0.amount == 4
        } == !finallyDefeated)
    }
}
