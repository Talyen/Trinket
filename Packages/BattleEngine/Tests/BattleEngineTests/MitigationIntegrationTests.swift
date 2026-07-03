import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

/// Integration tests for shield, armor, and mitigation through full battle ticks.
final class MitigationIntegrationTests: XCTestCase {
    func testShieldAbsorbsDamageBeforeHealth() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5, 10), remainingTicks: 10)
            ]
        )

        BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertEqual(battle.health(of: battle.hero), hero.maxHealth)
    }

    func testArmorMitigatesIncomingDamage() {
        let hero = BattleTestFixtures.passiveCombatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20, actionIntervalTicks: 2
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.judgment])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertEqual(battle.health(of: battle.hero), 17)
    }

    func testEffectiveDamageMatchesEventAmount() {
        let hero = BattleTestFixtures.passiveCombatant(
            id: "hero", name: "Hero", role: .hero, maxHealth: 20, actionIntervalTicks: 2
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.judgment])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 10), remainingTicks: 10)
            ]
        )

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)
        let damageEvent = events.first { $0.kind == .ability && $0.actorName == "Enemy" }

        XCTAssertEqual(damageEvent?.amount, 3)
        XCTAssertEqual(battle.health(of: battle.hero), 17)
    }

    func testSunderArmorHalvesEnemyArmor() {
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero, actionIntervalTicks: 2)
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.sunderArmor])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .mitigation(.armor, 0.40, 6), remainingTicks: 6)
            ]
        )

        BattleTestFixtures.advanceTicks(3, on: &battle)

        XCTAssertTrue(battle.hasEnemyEffect { effect in
            if case .mitigation(.armor, 0.20, _) = effect { return true }
            return false
        })
    }
}
