import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct AttackOnlyBonusRegressionTests {
    @Test(arguments: ["bear_physical_t1_1", "risen_skeleton_physical_t2_1"], [false, true])
    func `Physical attack Block talents preserve ordinary reaction Block removal`(talentID: String, attack: Bool) {
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)

        let result = battle.resolveDamage(DamageRequest(
            amount: 3, target: battle.enemy, keyword: .physical, sourceActorID: battle.companion.id,
            options: attack ? .attack(scaling: .flat, accuracy: .unavoidable) : .reaction(),
        ))

        #expect(result.healthLost == 0)
        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == (attack ? 4 : 7))
    }

    @Test func `Ogre Shieldbreaker does not double its Thorns Block removal`() throws {
        let ogre = try #require(GameContent.enemies.first { $0.id == "ogre" })
        var battle = BattleTestFixtures.makePipelineContext(enemyModifiers: CombatBuildResolver.build(enemy: ogre).modifiers)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.hero, in: &battle)
        battle.appendEffect(.thorns(3), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        let result = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))

        #expect(result.healthLost == 1)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 7)
    }

    @Test(arguments: [Keyword.physical, .holy])
    func `general Sundering and Holy Block damage multipliers still apply to reactions`(keyword: Keyword) {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(block: BlockTriggers(
            sunderingBlockMultiplier: 1, holyBlockBreakMultiplier: 2,
        )))
        var battle = BattleTestFixtures.makePipelineContext(companionModifiers: profile)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)

        _ = battle.resolveDamage(DamageRequest(
            amount: 3, target: battle.enemy, keyword: keyword, sourceActorID: battle.companion.id,
            options: .reaction(),
        ))

        #expect(BattleTestFixtures.shieldPoints(for: battle.enemy, in: battle) == 4)
    }
}
