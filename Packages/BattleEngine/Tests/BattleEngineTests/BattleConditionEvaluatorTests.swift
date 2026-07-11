import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct BattleConditionEvaluatorTests {
    @Test func lowestHealthAllyPrefersLivingCombatantWhenHeroIsDefeated() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 0 }
        context.roster.mutateRuntime(for: pet) { $0.currentHealth = 8 }

        let target = BattleConditionEvaluator.lowestHealthAlly(
            hero: hero,
            pet: pet,
            context: context
        )

        try #expect(target.id == pet.id)
    }

    @Test func enemyBleedingRequiresActiveBleedStack() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        let expiredBleed = ActiveEffect(id: 1, effect: .bleed(2), remainingTicks: 0, sourceActorID: hero.id)
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                pet: CombatantRuntime(combatant: pet),
                enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: [expiredBleed])
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )

        try #expect(!BattleConditionEvaluator.isMet(
            .enemyBleeding,
            actor: hero,
            enemy: enemy,
            hero: hero,
            pet: pet,
            context: context
        ))
    }
}
