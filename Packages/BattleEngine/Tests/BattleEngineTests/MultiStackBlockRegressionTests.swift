import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct MultiStackBlockRegressionTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `owned and borrowed Block spend all stacks before breaking the pool`(target: BattleParticipant) throws {
        let profile = CombatModifierProfile.withTriggers {
            $0.blockAbsorbsCompanionDamage = true
            $0.seismicReversal = true
            $0.criticalChanceBonus = -1
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
        battle.roster.setActiveEffects([
            ActiveEffect(id: 100, effect: .shield(.block, 2), remainingTurns: 0, sourceActorID: battle.hero.id),
            ActiveEffect(id: 101, effect: .shield(.block, 3), remainingTurns: 0, sourceActorID: battle.companion.id),
        ], for: battle.hero)

        func hit(_ amount: Int, in battle: inout BattleState) -> CombatOutcome {
            battle.resolveTestDamage(
                amount, to: battle.roster[target].combatant, keyword: .physical,
                sourceActorID: battle.enemy.id,
                options: .attack(scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            )
        }

        #expect(hit(3, in: &battle).healthLost == 0)
        let retained = try #require(battle.activeEffects(of: battle.hero).first { $0.effect.kind == .shield })
        #expect(retained.id == 101)
        #expect(retained.sourceActorID == battle.companion.id)
        #expect(retained.effect == .shield(.block, 2))
        #expect(battle.health(of: battle.enemy) == 100)

        #expect(hit(2, in: &battle).healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
        #expect(battle.health(of: battle.enemy) == 98)
        #expect(hit(1, in: &battle).healthLost == 1)
    }
}
