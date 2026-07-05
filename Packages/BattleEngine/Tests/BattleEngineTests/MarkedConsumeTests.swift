import XCTest
@testable import BattleEngine
import TrinketCore
import TrinketContent

final class MarkedConsumeTests: XCTestCase {
    func testMarkedNotConsumedWhenFullyShielded() {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30)
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 50, 6), remainingTicks: 6, sourceActorID: hero.id)
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
            petModifiers: .zero
        )

        let outcome = context.resolveDamage(
            .directAbilityHit(amount: 3, target: enemy, keyword: .physical, sourceActorID: hero.id)
        )

        XCTAssertEqual(outcome.healthLost, 0)
        XCTAssertTrue(
            context.roster.activeEffects(for: enemy).contains { if case .marked = $0.effect { return true }; return false }
        )
    }
}
