import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class EffectTickEngineTests: XCTestCase {
    private func makeContext(
        heroHP: Int = 50,
        enemyHP: Int = 50,
        enemyEffects: [ActiveEffect] = []
    ) -> BattleEngineContext {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialHealth: heroHP),
            pet: CombatantRuntime(combatant: pet),
            enemy: CombatantRuntime(combatant: enemy, initialHealth: enemyHP, initialActiveEffects: enemyEffects)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 10,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            petModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    func testDoTTickPreservesShieldDepletionThroughTickAll() {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 5, 5),
            remainingTicks: 5,
            sourceActorID: "caster"
        )
        let burn = ActiveEffect(id: 2, effect: .burn(4), remainingTicks: 0)
        var context = makeContext(enemyHP: 50, enemyEffects: [shield, burn])
        let enemy = context.roster.enemy.combatant

        let result = EffectTickEngine.tickEffects(
            context.roster.activeEffects(for: enemy),
            target: enemy,
            context: &context
        )
        context.roster.setActiveEffects(result.updated, for: enemy)

        let shields = context.roster.activeEffects(for: enemy).compactMap { activeEffect -> Int? in
            guard case let .shield(_, buffer, _) = activeEffect.effect else { return nil }
            return buffer
        }
        XCTAssertEqual(shields, [3], "Burn tick should erode the shield buffer before HP damage")
        XCTAssertEqual(context.roster.health(for: enemy), 50)
    }

    func testDoTTickPreservesDeathsDoorThroughTickAll() {
        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)
        var context = makeContext(heroHP: 1, enemyEffects: [])
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects([burn], for: hero)

        let result = EffectTickEngine.tickEffects(
            context.roster.activeEffects(for: hero),
            target: hero,
            context: &context
        )
        context.roster.setActiveEffects(result.updated, for: hero)

        XCTAssertEqual(context.roster.health(for: hero), 1)
        XCTAssertTrue(context.roster.isDeathsDoorActive(for: hero))
        XCTAssertTrue(
            context.roster.activeEffects(for: hero).contains { $0.effect.kind == .deathsDoor },
            "Death's Door inserted during DoT damage should survive effect-tick write-back"
        )
    }
}
