import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
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

    @Test(arguments: [0, 1], [false, true])
    func `bounty shot grants both outcomes against a marked enemy`(branchIndex: Int, marked: Bool) throws {
        let branches = try #require(Ability.bountyShot.outcomeBranches)
        let ability = Ability(
            id: Ability.bountyShot.id, name: Ability.bountyShot.name, tier: .skill,
            outcomeBranches: [branches[branchIndex]], stealsGold: true,
        )
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
        )
        context.appliesFightPacing = false
        if marked {
            context.appendEffect(.marked(1, 1), to: context.enemy, sourceID: context.hero.id, remainingTurns: 2)
        }
        let initialHealth = context.roster.enemy.currentHealth

        _ = BattleTurnEngine.performAction(
            ability: ability, actor: context.hero, abilityTarget: context.enemy, context: &context,
        )

        #expect(context.gold == (marked || branchIndex == 1 ? 3 : 0))
        #expect((context.roster.enemy.currentHealth < initialHealth) == (marked || branchIndex == 0))
    }
}
