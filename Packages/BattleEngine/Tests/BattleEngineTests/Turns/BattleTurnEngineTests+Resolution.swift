import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension BattleTurnEngineTests {
    @Test(arguments: ["the_frostwarden", "the_iron_bear"])
    func `enemy area trait stops when block retaliation defeats its source`(enemyID: String) throws {
        let definition = try #require(GameContent.enemy(matching: enemyID))
        let build = CombatBuildResolver.build(enemy: definition)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: build.combatant,
            enemyHealth: 1,
            heroModifiers: CombatModifierProfile.withTriggers { $0.blockBrokenSaintfallPower = 6 },
            enemyModifiers: build.modifiers, appliesFightPacing: false,
        )
        context.turnCount = 2
        DefensePoolEngine.set(1, on: context.hero, in: &context)

        if build.modifiers.triggers.turnFreezeDamageAllEnemies > 0 {
            CombatExecutor.run { await EnemyTraitEngine.turnFreeze(for: context.enemy, context: &context) }
        } else {
            CombatExecutor.run { await EnemyTraitEngine.turnRandomDamageAllEnemies(for: context.enemy, context: &context) }
        }

        #expect(context.roster.enemy.currentHealth == 0)
        #expect(context.roster.companion.currentHealth == 40)
        #expect(context.roster.companion.activeEffects.isEmpty)
    }

    @Test func `bounty shot deals fixed damage and gold without mark`() {
        let ability = Ability.bountyShot
        var context = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100), appliesFightPacing: false,
        )
        let initialHealth = context.roster.enemy.currentHealth

        _ = context.performTestAction(ability)

        #expect(context.gold == 2)
        #expect(context.roster.activeEffects(for: context.enemy).contains { $0.effect.keyword == .stun })
        #expect(!context.roster.activeEffects(for: context.enemy).contains { $0.effect.kind == .marked })
        #expect(context.roster.enemy.currentHealth == initialHealth - 3)
    }
}
