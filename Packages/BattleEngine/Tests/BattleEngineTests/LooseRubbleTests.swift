import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct LooseRubbleTests {
    private func battle() throws -> BattleState {
        let titan = try #require(GameContent.enemy(matching: "the_stone_titan"))
        let build = CombatBuildResolver.build(enemy: titan)
        return BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            enemy: build.combatant, heroModifiers: .withTriggers { $0.dodgeChanceBonus = -1 },
            enemyModifiers: build.modifiers, appliesFightPacing: false,
        )
    }

    @Test(arguments: [DamageOperation.attack(accuracy: .unavoidable), .periodic, .resolvedPeriodic, .reaction()])
    func `Health damage readies one attack reduction without stacking`(operation: DamageOperation) throws {
        var battle = try battle()
        for _ in 0 ..< 2 {
            battle.resolveTestDamage(1, options: operation)
        }
        let attack = Ability(
            id: "double_hit",
            name: "Double Hit",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical)],
        )
        for expected in [3, 4] {
            let health = battle.roster.hero.currentHealth
            let events = battle.performTestAction(attack, from: .enemy, to: .hero)
            #expect(health - battle.roster.hero.currentHealth == expected)
            #expect(events.filter { $0.effectKind == .damageReduced }.reduce(0) { $0 + $1.amount } == (expected == 3 ? 1 : 0))
        }
    }

    @Test func `ongoing damage reactions and support preserve the next attack reduction`() throws {
        var battle = try battle()
        battle.resolveTestDamage(1, options: .reaction())
        for operation in [DamageOperation.periodic, .reaction()] {
            let pulse = battle.resolveTestDamage(4, from: .enemy, to: .hero, options: operation)
            #expect(pulse.healthLost == 4)
        }
        battle.performTestAction(.stoneskinPotion, from: .enemy, to: .hero)
        let health = battle.roster.hero.currentHealth
        battle.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(health - battle.roster.hero.currentHealth == 2)
    }

    @Test func `fully blocked damage and Health costs do not ready a reduction`() throws {
        var battle = try battle()
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        for operation in [DamageOperation.reaction(), .healthCost] {
            battle.resolveTestDamage(1, options: operation)
        }
        let health = battle.roster.hero.currentHealth
        battle.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(health - battle.roster.hero.currentHealth == 3)
    }

    @Test func `a dodge preserves the reduction for the next landed attack`() throws {
        var battle = try battle()
        battle.resolveTestDamage(1, options: .reaction())
        battle.insertEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 1)
        let health = battle.roster.hero.currentHealth
        battle.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(battle.roster.hero.currentHealth == health)
        battle.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(health - battle.roster.hero.currentHealth == 2)
    }

    @Test func `the initial Earthquake pulse spends the attack reduction`() throws {
        var battle = try battle()
        battle.resolveTestDamage(1, options: .resolvedPeriodic)
        let health = battle.roster.hero.currentHealth
        battle.performTestAction(.earthquake, from: .enemy, to: .hero)
        #expect(health - battle.roster.hero.currentHealth == 5)
        #expect(battle.roster.enemy.talents.pending.nextDamageReduction == 0)
    }
}
