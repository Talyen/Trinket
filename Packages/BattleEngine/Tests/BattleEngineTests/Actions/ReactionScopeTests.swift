import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ReactionScopeTests {
    @Test func `talent reaction depth caps at 10 and restores`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxDepth) {
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
        #expect(state.resolution.depth(.damage) == ReactionScope.maxDepth)
    }

    @Test func `dot recursion depth caps at 10`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxDepth) {
            state.resolution.enter(.dot)
        }
        let events = CombatTriggerEngine.afterBleedApplied(to: target, sourceActorID: state.roster.hero.combatant.id, in: &state)
        #expect(events.isEmpty)
        #expect(state.resolution.depth(.dot) == ReactionScope.maxDepth)

        var state2 = BattleTestFixtures.makePipelineContext()
        for _ in 0 ..< (ReactionScope.maxDepth) {
            state2.resolution.enter(.dot)
        }
        let events2 = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .burn,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state2,
        )
        #expect(events2.isEmpty)
        #expect(state2.resolution.depth(.dot) == ReactionScope.maxDepth)
    }

    @Test func `dot recursion allows ten and truncates eleventh`() {
        var state = BattleTestFixtures.makePipelineContext()
        let target = state.roster.enemy.combatant
        for _ in 0 ..< (ReactionScope.maxDepth - 1) {
            state.resolution.enter(.dot)
        }
        let allowed = CombatTriggerEngine.afterDecayingDoTApplied(
            keyword: .poison,
            to: target,
            sourceActorID: state.roster.hero.combatant.id,
            in: &state,
        )
        #expect(allowed.isEmpty)
        #expect(state.resolution.depth(.dot) == ReactionScope.maxDepth - 1)
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

    @Test func `ward retaliation emits thorns decorator`() {
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(4), remainingTurns: 2)],
        )
        let outcome = state.resolveDamage(DamageRequest(
            amount: 10,
            target: state.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: state.roster.enemy.combatant.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(outcome.healthLost == 10)
        #expect(state.roster.health(for: state.roster.enemy.combatant) == 96)
        #expect(outcome.events.contains {
            $0.effectKind == .thornsTriggered && $0.abilityName == "Thorns"
                && $0.keyword == .physical && $0.amount == 4
        })
    }

    @Test func `talent strike nested damage emits no thorns decorator`() {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.basicAttackFreezeBuildup = 3
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: heroProfile,
        )
        let outcome = state.resolveDamage(DamageRequest(
            amount: 10,
            target: state.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: state.roster.hero.combatant.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(outcome.healthLost == 10)
        #expect(state.roster.health(for: state.roster.enemy.combatant) == 87)
        #expect(!outcome.events.contains { $0.effectKind == .thornsTriggered })
    }

    @Test func `later attack riders skip an enemy defeated by a prior rider`() {
        var heroProfile = CombatModifierProfile.zero
        heroProfile.triggers.partyBasicAttackHolyBonus = 3
        heroProfile.triggers.attackBurstChancePercent = 1
        heroProfile.triggers.attackBurstBlock = 5
        var state = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 3),
            heroModifiers: heroProfile,
        )
        let hero = state.roster.hero.combatant
        let enemy = state.roster.enemy.combatant

        let outcome = state.resolveDamage(DamageRequest(
            amount: 1,
            target: enemy,
            keyword: .physical,
            sourceActorID: hero.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        ))

        #expect(outcome.healthLost == 1)
        #expect(state.roster.health(for: enemy) == 0)
        #expect(DefensePoolEngine.blockPoints(in: state.roster.activeEffects(for: hero)) == 0)
    }
}
