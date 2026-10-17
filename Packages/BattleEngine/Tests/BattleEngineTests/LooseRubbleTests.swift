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
            enemy: build.combatant, enemyModifiers: build.modifiers, appliesFightPacing: false,
        )
    }

    @Test(arguments: [DamageOperation.attack(accuracy: .unavoidable), .periodic, .resolvedPeriodic, .reaction()])
    func `Health damage readies one reduction without stacking`(operation: DamageOperation) throws {
        var battle = try battle()
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(1, options: operation)
        }
        for expected in [3, 4] {
            let hit = battle.recordingResult { context in context.resolveTestDamage(4, from: .enemy, to: .hero, options: .reaction()) }
            #expect(hit.value.healthLost == expected)
            if expected == 3 {
                let reduction = try #require(hit.events.first { $0.effectKind == .damageReduced })
                #expect(reduction.amount == 1)
                #expect(!hit.events.contains { $0.kind == .status && $0.amount == 1 && $0.targetID == battle.hero.id })
            }
        }
    }

    @Test func `fully blocked damage and Health costs do not ready Loose Rubble`() throws {
        var battle = try battle()
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        for operation in [DamageOperation.reaction(), .healthCost] {
            _ = battle.resolveTestDamage(1, options: operation)
        }
        let hit = battle.resolveTestDamage(4, from: .enemy, to: .hero, options: .reaction())
        #expect(hit.healthLost == 4)
    }

    @Test func `a dodge preserves the reduction and a one-point pulse consumes it`() throws {
        var battle = try battle()
        _ = battle.resolveTestDamage(1, options: .reaction())
        battle.insertEffect(.evadeNextHit, to: battle.hero, sourceID: battle.hero.id, remainingTurns: 1)
        let dodge = battle.resolveTestDamage(4, from: .enemy, to: .hero)
        #expect(dodge.healthLost == 0)
        for expected in [0, 1] {
            let pulse = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .reaction())
            #expect(pulse.healthLost == expected)
        }
    }

    @Test func `damage can ready the reduction again after consumption`() throws {
        var battle = try battle()
        for _ in 0 ..< 2 {
            _ = battle.resolveTestDamage(1, options: .resolvedPeriodic)
            let hit = battle.resolveTestDamage(4, from: .enemy, to: .hero, keyword: .stun, options: .periodic)
            #expect(hit.healthLost == 3)
        }
    }
}
