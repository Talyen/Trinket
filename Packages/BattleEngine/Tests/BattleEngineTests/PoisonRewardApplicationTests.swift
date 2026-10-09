import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PoisonRewardApplicationTests {
    @Test(arguments: [0, 2, 4])
    func `Toxic Incense leaves only the Poison damage that passed Block`(block: Int) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "brass_censer"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.holyDamagePoisonFlat = 4
        var battle = makeBattle(profile: profile)
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.health(of: battle.enemy)

        _ = CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(
            to: battle.enemy, source: battle.hero, in: &battle,
        ) }

        let lost = 4 - block
        #expect(before - battle.health(of: battle.enemy) == lost)
        #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.kind == .poison }?.effect.potency == (lost > 0 ? lost : nil))
    }

    @Test(arguments: [0, 2, 4])
    func `Toxic Remedy leaves Poison from restored Health after enemy Block`(block: Int) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = makeBattle(profile: profile)
        battle.roster.hero.currentHealth = 5
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.health(of: battle.enemy)

        let result = battle.resolveHeal(HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.hero.id))

        #expect(result.healthRestored == 8)
        let lost = 4 - block
        #expect(before - battle.health(of: battle.enemy) == lost)
        #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.kind == .poison }?.effect.potency == (lost > 0 ? lost : nil))
    }

    private func makeBattle(profile: CombatModifierProfile) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
