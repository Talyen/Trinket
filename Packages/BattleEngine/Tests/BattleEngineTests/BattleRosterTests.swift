import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleRosterTests: XCTestCase {
    private func combatant(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int? = nil
    ) -> Combatant {
        Combatant(
            id: id,
            name: id.capitalized,
            role: role,
            maxHealth: maxHealth,
            actionIntervalTicks: actionIntervalTicks,
            abilities: []
        )
    }

    private func runtime(
        id: String,
        role: Combatant.Role,
        maxHealth: Int = 20,
        actionIntervalTicks: Int? = nil,
        initialHealth: Int? = nil,
        initialNextReadyAtTick: Int? = nil
    ) -> CombatantRuntime {
        CombatantRuntime(
            combatant: combatant(id: id, role: role, maxHealth: maxHealth, actionIntervalTicks: actionIntervalTicks),
            initialHealth: initialHealth,
            initialNextReadyAtTick: initialNextReadyAtTick
        )
    }

    private func makeRoster(
        hero: CombatantRuntime? = nil,
        pet: CombatantRuntime? = nil,
        enemy: CombatantRuntime? = nil
    ) -> BattleRoster {
        BattleRoster(
            hero: hero ?? runtime(id: "hero", role: .hero, actionIntervalTicks: 2),
            pet: pet ?? runtime(id: "pet", role: .pet, actionIntervalTicks: 2),
            enemy: enemy ?? runtime(id: "enemy", role: .enemy, actionIntervalTicks: 6)
        )
    }

    // MARK: - Dispatch by Combatant identity

    func testRuntimeForReturnsMatching() {
        let hero = runtime(id: "hero", role: .hero)
        let pet = runtime(id: "pet", role: .pet)
        let enemy = runtime(id: "enemy", role: .enemy)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        XCTAssertEqual(roster.runtime(for: hero.combatant)?.id, "hero")
        XCTAssertEqual(roster.runtime(for: pet.combatant)?.id, "pet")
        XCTAssertEqual(roster.runtime(for: enemy.combatant)?.id, "enemy")
    }

    func testRuntimeForReturnsNilForUnknownID() {
        let roster = makeRoster()
        let unknown = combatant(id: "stranger", role: .hero)
        XCTAssertNil(roster.runtime(for: unknown))
    }

    func testCombatantForReturnsRuntimeByID() {
        let roster = makeRoster()
        XCTAssertEqual(roster.combatant(for: "hero")?.role, .hero)
        XCTAssertEqual(roster.combatant(for: "pet")?.role, .pet)
        XCTAssertEqual(roster.combatant(for: "enemy")?.role, .enemy)
        XCTAssertNil(roster.combatant(for: "missing"))
    }

    func testUpdateReplacesMatchingRuntime() {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(5)
        roster.update(hero)

        XCTAssertEqual(roster.hero.currentHealth, hero.maxHealth - 5)
        XCTAssertEqual(roster.pet.currentHealth, roster.pet.maxHealth)
    }

    func testUpdateIgnoresUnknownRuntime() {
        var roster = makeRoster()
        let stranger = runtime(id: "stranger", role: .hero)
        roster.update(stranger)
        XCTAssertEqual(roster.hero.id, "hero")
    }

    // MARK: - Active effects

    func testActiveEffectsAndSetActiveEffects() {
        var roster = makeRoster()
        XCTAssertTrue(roster.activeEffects(for: roster.hero.combatant).isEmpty)

        let burn = ActiveEffect(id: 1, effect: .burn(3), remainingTicks: 0)
        roster.setActiveEffects([burn], for: roster.hero.combatant)
        XCTAssertEqual(roster.activeEffects(for: roster.hero.combatant), [burn])
    }

    // MARK: - Health

    func testHealthAndMaxHealth() {
        let hero = runtime(id: "hero", role: .hero, maxHealth: 10)
        let roster = BattleRoster(
            hero: hero,
            pet: runtime(id: "pet", role: .pet),
            enemy: runtime(id: "enemy", role: .enemy)
        )
        XCTAssertEqual(roster.health(for: hero.combatant), 10)
        XCTAssertEqual(roster.maxHealth(for: hero.combatant), 10)
    }

    // MARK: - Ready-actor picker

    func testReadyCombatantsReturnsNothingBeforeAnyReady() {
        let roster = makeRoster()
        XCTAssertTrue(roster.readyCombatants(atTick: 0).isEmpty)
    }

    func testReadyCombatantsRespectsIndividualReadyTicks() {
        let hero = runtime(id: "hero", role: .hero, actionIntervalTicks: 2)
        let pet = runtime(id: "pet", role: .pet, actionIntervalTicks: 4)
        let enemy = runtime(id: "enemy", role: .enemy, actionIntervalTicks: 6)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(roster.readyCombatants(atTick: 1).isEmpty)
        XCTAssertEqual(roster.readyCombatants(atTick: 2).map(\.id), ["hero"])
        XCTAssertEqual(roster.readyCombatants(atTick: 3).map(\.id), ["hero"])
        XCTAssertEqual(roster.readyCombatants(atTick: 4).map(\.id), ["hero", "pet"])
        XCTAssertEqual(roster.readyCombatants(atTick: 5).map(\.id), ["hero", "pet"])
        XCTAssertEqual(roster.readyCombatants(atTick: 6).map(\.id), ["hero", "pet", "enemy"])
    }

    func testReadyCombatantsSortsByReadyAtTickThenIntervalThenRoleOrder() {
        let fastPet = runtime(id: "fastpet", role: .pet, actionIntervalTicks: 1, initialNextReadyAtTick: 5)
        let slowHero = runtime(id: "slowhero", role: .hero, actionIntervalTicks: 4, initialNextReadyAtTick: 5)
        let roster = BattleRoster(
            hero: slowHero,
            pet: fastPet,
            enemy: runtime(id: "enemy", role: .enemy, actionIntervalTicks: 100)
        )
        // Both ready at tick 5. fastPet has longer interval (4 vs ... wait, 1 vs 4).
        // Sorted by interval descending → slowHero (4) first, then fastPet (1).
        let ready = roster.readyCombatants(atTick: 5)
        XCTAssertEqual(ready.map(\.id), ["slowhero", "fastpet"])
    }

    func testReadyCombatantsUsesRoleOrderTiebreaker() {
        // Same interval, same ready tick → hero (0) before pet (1) before enemy (2).
        let hero = runtime(id: "hero", role: .hero, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let pet = runtime(id: "pet", role: .pet, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let enemy = runtime(id: "enemy", role: .enemy, actionIntervalTicks: 2, initialNextReadyAtTick: 2)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: enemy)
        let ready = roster.readyCombatants(atTick: 2)
        XCTAssertEqual(ready.map(\.id), ["hero", "pet", "enemy"])
    }

    func testReadyCombatantsExcludesDefeated() {
        var roster = makeRoster()
        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        XCTAssertFalse(roster.readyCombatants(atTick: 100).contains { $0.role == .enemy })
    }

    // MARK: - Targeting

    func testEnemyAttackTargetPrefersHeroWhenBothAlive() {
        let roster = makeRoster()
        XCTAssertEqual(roster.enemyAttackTarget.id, "hero")
    }

    func testEnemyAttackTargetFallsBackToPetWhenHeroDead() {
        var roster = makeRoster()
        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        XCTAssertEqual(roster.enemyAttackTarget.id, "pet")
    }

    func testEnemyAttackTargetPrefersHigherHealthWhenBothAlive() {
        let hero = runtime(id: "hero", role: .hero, initialHealth: 5)
        let pet = runtime(id: "pet", role: .pet, initialHealth: 10)
        let roster = BattleRoster(hero: hero, pet: pet, enemy: runtime(id: "enemy", role: .enemy))
        XCTAssertEqual(roster.enemyAttackTarget.id, "pet")
    }

    // MARK: - Defeat flags

    func testIsPartyDefeatedRequiresBothDown() {
        var roster = makeRoster()
        XCTAssertFalse(roster.isPartyDefeated)

        var hero = roster.hero
        hero.takeRawDamage(999)
        roster.update(hero)
        XCTAssertFalse(roster.isPartyDefeated)

        var pet = roster.pet
        pet.takeRawDamage(999)
        roster.update(pet)
        XCTAssertTrue(roster.isPartyDefeated)
    }

    func testIsEnemyDefeated() {
        var roster = makeRoster()
        XCTAssertFalse(roster.isEnemyDefeated)

        var enemy = roster.enemy
        enemy.takeRawDamage(999)
        roster.update(enemy)
        XCTAssertTrue(roster.isEnemyDefeated)
    }
}
