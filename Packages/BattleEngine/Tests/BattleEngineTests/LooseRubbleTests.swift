import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct LooseRubbleTests {
    private func battle() throws -> BattleState {
        let titan = try #require(GameContent.enemy(matching: "the_stone_titan"))
        let build = CombatBuildResolver.build(enemy: titan)
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: build.combatant, enemyModifiers: build.modifiers,
        )
        battle.appliesFightPacing = false
        return battle
    }

    @Test(arguments: [DamageOperation.attack(accuracy: .unavoidable), .periodic, .resolvedPeriodic, .reaction()])
    func `Health damage readies one reduction without stacking`(operation: DamageOperation) throws {
        var battle = try battle()
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: operation,
            ))
        }
        for expected in [3, 4] {
            let hit = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.hero, keyword: .physical,
                sourceActorID: battle.enemy.id, options: .reaction(),
            ))
            #expect(hit.healthLost == expected)
        }
    }

    @Test func `fully blocked damage and Health costs do not ready Loose Rubble`() throws {
        var battle = try battle()
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        for operation in [DamageOperation.reaction(), .healthCost] {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: operation,
            ))
        }
        let hit = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .reaction(),
        ))
        #expect(hit.healthLost == 4)
    }

    @Test func `a dodge preserves the reduction and a one-point pulse consumes it`() throws {
        var battle = try battle()
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .reaction(),
        ))
        battle.appendEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 1)
        let dodge = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id, options: .attack(),
        ))
        #expect(dodge.healthLost == 0)
        for expected in [0, 1] {
            let pulse = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.hero, keyword: .physical,
                sourceActorID: battle.enemy.id, options: .reaction(),
            ))
            #expect(pulse.healthLost == expected)
        }
    }

    @Test func `damage can ready the reduction again after consumption`() throws {
        var battle = try battle()
        for _ in 0 ..< 2 {
            _ = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.enemy, keyword: .physical,
                sourceActorID: battle.hero.id, options: .resolvedPeriodic,
            ))
            let hit = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.hero, keyword: .stun,
                sourceActorID: battle.enemy.id, options: .periodic,
            ))
            #expect(hit.healthLost == 3)
        }
    }
}
