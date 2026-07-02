import XCTest
@testable import Trinket

/// Integration tests for healing and leech through full battle ticks.
final class RestorationIntegrationTests: XCTestCase {
    func testInstantHealRestoresHealth() {
        let heal = Ability(
            id: "heal",
            name: "Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 3 Health.",
            effects: [.instantHeal(.health, 3)]
        )
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [heal])
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        _ = battle.advanceOneStep()
        XCTAssertEqual(battle.heroHealth, 8)

        let events = battle.advanceOneStep().events

        XCTAssertEqual(battle.heroHealth, 10)
        XCTAssertTrue(events.contains { event in
            event.effectKind == .instantHeal && ActionEventFormatter.display(for: event).text == "+3 Health"
        })
    }

    func testLeechHealsAttackerOnDamageDealt() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 10, actionIntervalTicks: 2, abilities: [.slash])
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.passiveCombatant(id: "enemy", name: "Enemy", role: .enemy)
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .burn(5), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .standardLeechBuff, remainingTicks: 6)
            ]
        )

        _ = battle.advanceOneStep()
        XCTAssertEqual(battle.heroHealth, 8)

        let events = battle.advanceOneStep().events

        XCTAssertEqual(battle.heroHealth, 8)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal && $0.keyword == .leech })
    }

    /// Verifies that an enemy `instantHeal` ability restores health when below max.
    /// Uses `activeEnemyEffects` burn to pre-damage the enemy before it acts.
    func testEnemyInstantHealRestoresHealthWhenBelowMax() {
        let selfHeal = Ability(
            id: "self-heal",
            name: "Self Heal",
            tier: .basic,
            directDamage: 0,
            description: "Restore 5 Health.",
            effects: [.instantHeal(.health, 5)]
        )
        let hero = BattleTestFixtures.passiveCombatant(id: "hero", name: "Hero", role: .hero)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = Combatant(
            id: "enemy", name: "Enemy", role: .enemy, maxHealth: 20,
            actionIntervalTicks: 1,
            abilities: [selfHeal]
        )
        var battle = BattleTestFixtures.standardParty(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        let step = battle.advanceOneStep()

        XCTAssertTrue(step.events.contains { $0.effectKind == .instantHeal && $0.amount == 5 })
        XCTAssertEqual(battle.enemyHealth, 20)
    }
}
