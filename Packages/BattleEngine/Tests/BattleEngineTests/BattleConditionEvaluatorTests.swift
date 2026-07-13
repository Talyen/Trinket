import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleConditionEvaluatorTests {
    @Test func lowestHealthAllyPrefersLivingCombatantWhenHeroIsDefeated() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        context.roster.mutateRuntime(for: companion) { $0.currentHealth = 8 }

        let target = BattleConditionEvaluator.lowestHealthAlly(
            hero: hero,
            companion: companion,
            context: context
        )

        try #expect(target.id == companion.id)
    }

    @Test func enemyBleedingRequiresActiveBleedStack() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        let expiredBleed = ActiveEffect(id: 1, effect: .bleed(2), remainingTicks: 0, sourceActorID: hero.id)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: [expiredBleed])
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        try #expect(!BattleConditionEvaluator.isMet(
            .enemyBleeding,
            actor: hero,
            enemy: enemy,
            hero: hero,
            companion: companion,
            context: context
        ))
    }
}
