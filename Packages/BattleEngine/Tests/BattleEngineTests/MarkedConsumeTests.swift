import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct MarkedConsumeTests {
    @Test func markedConsumedWhenFullyShielded() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 50), remainingTurns: 6, sourceActorID: hero.id)
        let mark = ActiveEffect(id: 2, effect: .marked(5, 6), remainingTurns: 6, sourceActorID: hero.id)

        let heroRuntime = CombatantRuntime(combatant: hero)
        let enemyRuntime = CombatantRuntime(combatant: enemy, initialActiveEffects: [shield, mark])
        var context = BattleState(
            roster: BattleRoster(
                hero: heroRuntime,
                companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
                enemy: enemyRuntime
            ),
            rng: SeededRandomNumberGenerator(seed: BattleTestFixtures.deterministicNonCriticalSeed),
            nextEffectID: 3,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        let outcome = context.resolveDamage(
            DamageRequest.directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id)
        )

        try #expect(outcome.healthLost == 0)
        try #expect(
            !context.roster.activeEffects(for: enemy).contains {
                if case .marked = $0.effect {
                    return true
                }; return false
            }
        )
        try #expect(outcome.events.contains { $0.effectKind == .markedConsumed })
    }
}
