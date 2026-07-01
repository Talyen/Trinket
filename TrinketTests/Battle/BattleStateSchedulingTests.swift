import XCTest
@testable import Trinket

final class BattleStateSchedulingTests: XCTestCase {
    private lazy var wolfPet = GameContent.pets.first { $0.id == "wolf" }!

    private func advance(_ battle: inout BattleState) -> BattleStep {
        battle.advanceOneStep()
    }

    func testAdvanceOneStepReturnsEndedWhenBattleOver() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: fragile, pet: helper, enemy: enemy)

        while !battle.isBattleOver {
            _ = advance(&battle)
        }

        if case let .ended(events) = advance(&battle) {
            XCTAssertTrue(events.isEmpty)
        } else {
            XCTFail("Expected ended step when battle is over")
        }
    }

    func testFirstActionIsHeroOnSecondTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case .effectsOnly = advance(&battle) {
            // tick 1: nobody acts
        } else {
            XCTFail("Expected effects-only step on tick 1")
        }

        if case let .acted(actor, events) = advance(&battle) {
            XCTAssertEqual(actor.id, hero.id)
            XCTAssertEqual(events.filter { $0.kind == .ability }.map(\.actorName), ["Hero"])
        } else {
            XCTFail("Expected hero to act on tick 2")
        }

        XCTAssertEqual(battle.enemyActionCount, 0)
    }

    func testPetActsOnThirdTickAfterHero() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        _ = advance(&battle)

        if case let .acted(actor, events) = advance(&battle) {
            XCTAssertEqual(actor.id, pet.id)
            XCTAssertEqual(events.filter { $0.kind == .ability }.map(\.actorName), ["Pet"])
        } else {
            XCTFail("Expected pet to act on tick 3")
        }
    }

    func testOnlyOneActorActsPerStep() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)
        let petStep = advance(&battle)

        if case let .acted(heroActor, heroEvents) = heroStep {
            XCTAssertEqual(heroActor.id, hero.id)
            XCTAssertEqual(heroEvents.filter { $0.kind == .ability }.count, 1)
        } else {
            XCTFail("Expected hero step")
        }

        if case let .acted(petActor, petEvents) = petStep {
            XCTAssertEqual(petActor.id, pet.id)
            XCTAssertEqual(petEvents.filter { $0.kind == .ability }.count, 1)
        } else {
            XCTFail("Expected pet step")
        }
    }

    func testEnemyAttacksOnSixthTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 50, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 50, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        for _ in 0 ..< 5 {
            _ = advance(&battle)
        }
        XCTAssertEqual(battle.enemyActionCount, 0)

        if case let .acted(actor, _) = advance(&battle) {
            XCTAssertEqual(actor.id, enemy.id)
        } else {
            XCTFail("Expected enemy to act on tick 6")
        }
        XCTAssertEqual(battle.enemyActionCount, 1)
        XCTAssertEqual(battle.tickCount, 6)
    }

    func testFastEnemyActsBeforePartyOnSeparateSteps() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: 100,
            actionIntervalTicks: 1,
            abilities: [.slash]
        )
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case let .acted(actor, _) = advance(&battle) {
            XCTAssertEqual(actor.id, enemy.id)
        } else {
            XCTFail("Expected enemy on tick 1")
        }

        if case let .acted(actor, _) = advance(&battle) {
            XCTAssertEqual(actor.id, hero.id)
        } else {
            XCTFail("Expected hero on tick 2")
        }

        if case let .acted(actor, _) = advance(&battle) {
            XCTAssertEqual(actor.id, pet.id)
        } else {
            XCTFail("Expected pet on tick 3")
        }
    }

    func testBurnEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(4), remainingTicks: 0)
            ]
        )

        XCTAssertFalse(battle.enemyEffectSummaries.filter { $0.keyword == .burn }.isEmpty)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        XCTAssertTrue(battle.enemyEffectSummaries.filter { $0.keyword == .burn }.isEmpty)
    }

    func testPoisonEffectExpiresAfterDuration() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .poison(4), remainingTicks: 0)
            ]
        )

        XCTAssertFalse(battle.enemyEffectSummaries.filter { $0.keyword == .poison }.isEmpty)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        _ = advance(&battle)
        XCTAssertTrue(battle.enemyEffectSummaries.filter { $0.keyword == .poison }.isEmpty)
    }

    func testEffectsOnlyStepWhenNobodyReady() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleStateTestFactory.makeBattle(hero: hero, pet: pet, enemy: enemy)

        if case .effectsOnly = advance(&battle) {
            XCTAssertEqual(battle.tickCount, 1)
        } else {
            XCTFail("Expected passive tick before first actions")
        }
    }

    func testWildcardHeroFirstActionGrantsExactGold() throws {
        let wildcard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wildcard" })
        var battle = BattleStateTestFactory.makeBattle(hero: wildcard, pet: wolfPet, enemy: defaultEnemy, initialGold: 10)

        _ = advance(&battle)
        _ = advance(&battle)

        XCTAssertEqual(battle.gold, 11)
        XCTAssertEqual(battle.earnedGold, 1)
    }

    private var defaultEnemy: Combatant {
        GameContent.enemies.first!.combatant
    }
}
