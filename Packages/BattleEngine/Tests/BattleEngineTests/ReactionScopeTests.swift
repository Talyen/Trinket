import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ReactionScopeTests {
    @Test func talentReactionDepthCapsAt10AndRestores() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        state.talentReactionDepth = ReactionScope.maxTalentReactionDepth
        let request = DamageRequest(
            amount: 10,
            target: target,
            keyword: .physical,
            sourceActorID: state.roster.hero.combatant.id,
            options: DamageOptions()
        )
        let outcome = state.resolveDamage(request)
        #expect(outcome.events.isEmpty)
        #expect(state.talentReactionDepth == ReactionScope.maxTalentReactionDepth)
    }

    @Test func dotRecursionDepthCapsAt10() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        state.dotRecursionDepth = ReactionScope.maxDotRecursionDepth
        let events = CombatTriggerEngine.afterBleedApplied(to: target, sourceActorID: state.roster.hero.combatant.id, in: &state)
        #expect(events.isEmpty)
        #expect(state.dotRecursionDepth == ReactionScope.maxDotRecursionDepth)

        var state2 = BattleTestFixtures.makePipelineContext()
        state2.dotRecursionDepth = ReactionScope.maxDotRecursionDepth
        let events2 = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .burn,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state2
        )
        #expect(events2.isEmpty)
        #expect(state2.dotRecursionDepth == ReactionScope.maxDotRecursionDepth)
    }

    @Test func dotRecursionAllowsTenAndTruncatesEleventh() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        state.dotRecursionDepth = ReactionScope.maxDotRecursionDepth - 1
        let allowed = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .poison,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state
        )
        #expect(allowed.isEmpty)
        #expect(state.dotRecursionDepth == ReactionScope.maxDotRecursionDepth - 1)
    }

    @Test func buildupDamageInvariantHoldsForBlockedHit() {
        let hero = BattleTestFixtures.passiveHero(maxHealth: 100)
        var state = BattleTestFixtures.makeContext(
            hero: hero,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(maxHealth: 100)
        )
        let target = state.roster.hero.combatant
        state.seedActiveEffects([ActiveEffect(id: 1, effect: .shield(.block, 999), remainingTurns: 2)], for: target)
        let request = DamageRequest(
            amount: 20,
            target: target,
            keyword: .physical,
            sourceActorID: state.roster.enemy.combatant.id,
            options: DamageOptions()
        )
        let outcome = state.resolveDamage(request)
        #expect(outcome.healthLost == 0)
        #expect(state.roster.health(for: target) == 100)
    }
}
