import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HomesteadCombatModifierTests {
    @Test func manaCostReductionRoundsDownAndAllowsZero() throws {
        var profile = CombatModifierProfile.zero
        profile.merge(.manaCostReductionPercent(0.15))

        let ability = Ability(
            id: "test-ability",
            name: "Test",
            tier: .skill,
            manaCost: 4
        )
        try #expect(profile.effectiveManaCost(for: ability) == 3)

        profile.merge(.manaCostReductionPercent(0.85))
        try #expect(profile.effectiveManaCost(for: ability) == 0)
    }

    @Test func poisonDamagePercentScalesDamageAfterFlatBonuses() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(modifiers: [
                .damageDealt(.poison, 2),
                .poisonDamageDealtPercent(0.2),
            ]),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        let outcome = context.resolveDamage(.doTTick(
            amount: 10,
            target: enemy,
            keyword: .poison,
            sourceActorID: hero.id
        ))

        try #expect(outcome.healthLost == 14)
    }
}
