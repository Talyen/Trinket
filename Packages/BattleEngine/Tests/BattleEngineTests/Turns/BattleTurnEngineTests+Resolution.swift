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
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(blockBrokenSaintfallPower: 6),
            )),
            enemyModifiers: build.modifiers,
        )
        context.appliesFightPacing = false
        context.turnCount = 2
        DefensePoolEngine.set(1, on: context.hero, in: &context)

        if build.modifiers.triggers.turnFreezeDamageAllEnemies > 0 {
            _ = EnemyTraitEngine.turnFreeze(for: context.enemy, context: &context)
        } else {
            _ = EnemyTraitEngine.turnRandomDamageAllEnemies(for: context.enemy, context: &context)
        }

        #expect(context.roster.enemy.currentHealth == 0)
        #expect(context.roster.companion.currentHealth == 40)
        #expect(context.roster.companion.activeEffects.isEmpty)
    }

    @Test func `bounty shot deals fixed damage and gold without mark`() throws {
        let ability = Ability.bountyShot
        try #expect(ability.outcomeBranches == nil)
        try #expect(ability.summary == "Deal 3 Stun damage\nSteal 2 Gold")
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
        )
        context.appliesFightPacing = false
        let initialHealth = context.roster.enemy.currentHealth

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )

        #expect(context.gold == 2)
        #expect(context.roster.activeEffects(for: context.enemy).contains { $0.effect.keyword == .stun })
        #expect(context.roster.enemy.currentHealth < initialHealth)
    }
}
