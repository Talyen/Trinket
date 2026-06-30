import XCTest
@testable import Trinket

final class BattleStateSchedulingTests: XCTestCase {
    private lazy var wolfPet = GameContent.pets.first { $0.id == "wolf" }!

    func testPerformNextActionReturnsEmptyWhenBattleOver() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: fragile, pet: helper, enemy: enemy)

        while !battle.isBattleOver {
            _ = battle.performNextAction()
        }

        XCTAssertTrue(battle.performNextAction().isEmpty)
    }

    func testFirstActionOrderIsHeroThenPetBeforeEnemy() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        let events = battle.performNextAction()
        let abilityActors = events.filter { $0.kind == .ability }.map(\.actorName)

        XCTAssertEqual(abilityActors, ["Hero", "Pet"])
        XCTAssertEqual(battle.enemyActionCount, 0)
    }

    func testEnemyAttacksOnThirdTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 50, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.performNextAction()
        _ = battle.performNextAction()
        XCTAssertEqual(battle.enemyActionCount, 0)

        _ = battle.performNextAction()
        XCTAssertEqual(battle.enemyActionCount, 1)
        XCTAssertEqual(battle.tickCount, 3)
    }

    func testBurnEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .damageOverTime(.burn, 1, 2), remainingTicks: 2)
            ]
        )

        XCTAssertFalse(battle.enemyEffectSummaries.filter { $0.keyword == .burn }.isEmpty)
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        XCTAssertTrue(battle.enemyEffectSummaries.filter { $0.keyword == .burn }.isEmpty)
    }

    func testPoisonEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .damageOverTime(.poison, 1, 2), remainingTicks: 2)
            ]
        )

        XCTAssertFalse(battle.enemyEffectSummaries.filter { $0.keyword == .poison }.isEmpty)
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        XCTAssertTrue(battle.enemyEffectSummaries.filter { $0.keyword == .poison }.isEmpty)
    }

    func testWildcardHeroFirstActionGrantsExactGold() {
        let wildcard = GameContent.heroes.first { $0.id == "wildcard" }!
        var battle = BattleState(hero: wildcard, pet: wolfPet, enemy: defaultEnemy, initialGold: 10)

        _ = battle.performNextAction()

        XCTAssertEqual(battle.gold, 11)
        XCTAssertEqual(battle.earnedGold, 1)
    }

    private var defaultEnemy: Combatant {
        GameContent.enemies.first!.combatant
    }
}
