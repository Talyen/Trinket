import Testing
import TrinketTestSupport
@testable import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct MarkedConsumeTests {
    @Test func markedConsumedWhenFullyShielded() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 50), remainingTicks: 6, sourceActorID: hero.id)
        let mark = ActiveEffect(id: 2, effect: .marked(5, 6), remainingTicks: 6, sourceActorID: hero.id)

        let heroRuntime = CombatantRuntime(combatant: hero)
        let enemyRuntime = CombatantRuntime(combatant: enemy, initialActiveEffects: [shield, mark])
        var context = BattleEngineContext(
            roster: BattleRoster(
                hero: heroRuntime,
                pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
                enemy: enemyRuntime
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 3,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )

        let outcome = context.resolveDamage(
            DamageRequest.directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id)
        )

        try #expect(outcome.healthLost == 0)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains { if case .marked = $0.effect { return true }; return false }
        )
        try #expect(outcome.events.contains { $0.effectKind == .markedConsumed })
    }
}
