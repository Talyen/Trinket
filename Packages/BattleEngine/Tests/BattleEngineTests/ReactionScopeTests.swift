import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct ReactionScopeTests {
    @Test func `talent reaction depth caps at 10 and restores`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxTalentReactionDepth) {
            state.resolution.enter(.damage)
        }
        let request = DamageRequest(
            amount: 10,
            target: target,
            keyword: .physical,
            sourceActorID: state.roster.hero.combatant.id,
            options: DamageOperation.effect(scaling: .statsAndItems, accuracy: .normal),
        )
        let outcome = state.resolveDamage(request)
        #expect(outcome.events.isEmpty)
        #expect(state.resolution.depth(.damage) == ReactionScope.maxTalentReactionDepth)
    }

    @Test func `dot recursion depth caps at 10`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxDotRecursionDepth) {
            state.resolution.enter(.dot)
        }
        let events = CombatTriggerEngine.afterBleedApplied(to: target, sourceActorID: state.roster.hero.combatant.id, in: &state)
        #expect(events.isEmpty)
        #expect(state.resolution.depth(.dot) == ReactionScope.maxDotRecursionDepth)

        var state2 = BattleTestFixtures.makePipelineContext()
        for _ in 0 ..< (ReactionScope.maxDotRecursionDepth) {
            state2.resolution.enter(.dot)
        }
        let events2 = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .burn,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state2,
        )
        #expect(events2.isEmpty)
        #expect(state2.resolution.depth(.dot) == ReactionScope.maxDotRecursionDepth)
    }

    @Test func `dot recursion allows ten and truncates eleventh`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxDotRecursionDepth - 1) {
            state.resolution.enter(.dot)
        }
        let allowed = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .poison,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state,
        )
        #expect(allowed.isEmpty)
        #expect(state.resolution.depth(.dot) == ReactionScope.maxDotRecursionDepth - 1)
    }

    @Test func `buildup damage invariant holds for blocked hit`() {
        let hero = CombatantFixtures.passiveHero(maxHealth: 100)
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
        )
        let target = state.roster.hero.combatant
        state.seedActiveEffects([ActiveEffect(id: 1, effect: .shield(.block, 999), remainingTurns: 2)], for: target)
        let request = DamageRequest(
            amount: 20,
            target: target,
            keyword: .physical,
            sourceActorID: state.roster.enemy.combatant.id,
            options: DamageOperation.effect(scaling: .statsAndItems, accuracy: .normal),
        )
        let outcome = state.resolveDamage(request)
        #expect(outcome.healthLost == 0)
        #expect(state.roster.health(for: target) == 100)
    }
}
