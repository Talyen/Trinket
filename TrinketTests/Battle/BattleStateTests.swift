import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    private lazy var defaultEnemy = GameContent.enemies.first!.combatant
    private lazy var wolfPet = GameContent.pets.first { $0.id == "wolf" }!

    private func advance(_ battle: inout BattleState) -> BattleStep {
        battle.advanceOneStep()
    }

    func testHeroActsOnSecondTickPetOnThird() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        var battle = BattleState(hero: hero, pet: pet, enemy: defaultEnemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)
        let petStep = advance(&battle)

        if case let .acted(actor, events) = heroStep {
            XCTAssertEqual(actor.id, hero.id)
            XCTAssertEqual(events.filter { $0.kind == .ability }.map(\.actorName), ["Hero"])
        } else {
            XCTFail("Expected hero step")
        }

        if case let .acted(actor, events) = petStep {
            XCTAssertEqual(actor.id, pet.id)
            XCTAssertEqual(events.filter { $0.kind == .ability }.map(\.actorName), ["Pet"])
        } else {
            XCTFail("Expected pet step")
        }
    }

    func testEnemyHealthDecreasesOnHit() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let initial = battle.enemyHealth
        _ = advance(&battle)
        _ = advance(&battle)
        XCTAssertLessThan(battle.enemyHealth, initial)
    }

    func testEnemyAttackTargetPrefersHigherHealthMember() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let target = battle.enemyAttackTarget
        XCTAssertEqual(target.id, heroId)
    }

    func testBurnDealsDamageAfterApplication() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: wolfPet, enemy: defaultEnemy)
        _ = advance(&battle)
        let applyStep = advance(&battle)
        XCTAssertTrue(applyStep.events.contains { $0.floatingText == "-2 Burn" })
        let tickStep = advance(&battle)
        XCTAssertTrue(tickStep.events.contains { $0.floatingText == "-1 Burn" })
    }

    func testPartyDefeatWhenBothHeroAndPetDie() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: fragile, pet: helper, enemy: enemy)
        while !battle.isBattleOver {
            _ = advance(&battle)
        }
        XCTAssertTrue(battle.isPartyDefeated)
        XCTAssertFalse(battle.isEnemyDefeated)
    }

    func testSmiteDealsHolyDamageType() {
        let smite = Ability.smite
        XCTAssertEqual(smite.damageKeyword, .holy)
        XCTAssertEqual(smite.damageType, .holy)
    }

    func testPoisonDaggerDealsPoisonDamageAndDot() {
        let ability = Ability.poisonDagger
        XCTAssertEqual(ability.damageKeyword, .poison)
        XCTAssertEqual(ability.damageType, .poison)
        let hasPoisonDot = ability.effects.contains {
            if case .poison = $0 { return true }
            return false
        }
        XCTAssertTrue(hasPoisonDot)
    }

    func testSerratedEdgeDealsBleedDamageAndDot() {
        let ability = Ability.serratedEdge
        XCTAssertEqual(ability.damageKeyword, .bleed)
        let hasBleedDot = ability.effects.contains {
            if case .bleed = $0 { return true }
            return false
        }
        XCTAssertTrue(hasBleedDot)
    }

    func testJudgmentDealsHolyDamageAndStuns() {
        let ability = Ability.judgment
        XCTAssertEqual(ability.damageKeyword, .holy)
        let hasStun = ability.effects.contains {
            if case .prevention(.stun, _) = $0 { return true }
            return false
        }
        XCTAssertTrue(hasStun)
    }

    func testBattleTracksGoldFromResourceGains() throws {
        let wildcard = try XCTUnwrap(GameContent.heroes.first { $0.id == "wildcard" })
        var battle = BattleState(hero: wildcard, pet: wolfPet, enemy: defaultEnemy, initialGold: 10)
        _ = advance(&battle)
        _ = advance(&battle)
        XCTAssertEqual(battle.gold, 11)
    }

    func testInitialGoldReflectedInEarnedGold() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: wolfPet, enemy: defaultEnemy, initialGold: 5)
        _ = advance(&battle)
        _ = advance(&battle)
        XCTAssertEqual(battle.earnedGold, battle.gold - 5)
    }

    func testBattleSimulatorDeterministicWithSeed() {
        let hero = GameContent.heroes[2]
        let result1 = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: BattleSimulationOptions(seed: 42))
        let result2 = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: BattleSimulationOptions(seed: 42))
        XCTAssertEqual(result1.events.map(\.floatingText), result2.events.map(\.floatingText))
        XCTAssertEqual(result1.metrics, result2.metrics)
    }

    func testBattleVictoryOutcome() {
        let hero = GameContent.heroes[2]
        let result = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy)
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.victory)
        XCTAssertTrue(result.didWin)
    }

    func testTickLimitWhenBattleCannotFinish() {
        let watcher = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let enemy = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])
        let result = BattleSimulator.run(hero: watcher, pet: observer, enemy: enemy, maxTicks: 3)
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.tickLimit)
        XCTAssertTrue(result.didHitTickLimit)
    }

    func testDefeatWhenPartyIsObliterated() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: fragile, pet: observer, enemy: enemy)
        XCTAssertEqual(result.outcome, BattleSimulationOutcome.defeat)
    }

    func testBurnAndPoisonStackIndependently() {
        var battle = BattleState(
            hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(2), remainingTicks: 0),
                ActiveEffect(id: 2, effect: .poison(4), remainingTicks: 0)
            ]
        )
        _ = advance(&battle)
        let summaries = battle.enemyEffectSummaries
        let burnSummary = summaries.first { $0.keyword == .burn }
        let poisonSummary = summaries.first { $0.keyword == .poison }
        XCTAssertNotNil(burnSummary)
        XCTAssertNotNil(poisonSummary)
    }

    func testPetSkipsActionWhenHeroKillsEnemySameStep() {
        let finisher = Ability(id: "finisher", name: "Finisher", tier: .basic, directDamage: 1, description: "Finisher")
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [finisher])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 1, abilities: [])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = advance(&battle)
        let heroStep = advance(&battle)

        XCTAssertTrue(battle.isEnemyDefeated)
        if case let .acted(actor, events) = heroStep {
            XCTAssertEqual(actor.id, hero.id)
            XCTAssertFalse(events.contains { $0.actorName == "Pet" && $0.kind == .ability })
        } else if case let .ended(events) = heroStep {
            XCTAssertFalse(events.contains { $0.actorName == "Pet" && $0.kind == .ability })
        } else {
            XCTFail("Expected hero to act before battle ended")
        }

        let petStep = advance(&battle)
        if case .ended = petStep {
            XCTAssertTrue(true)
        } else if case let .acted(actor, _) = petStep {
            XCTFail("Pet should not act after enemy defeat, got \(actor.name)")
        } else {
            XCTAssertTrue(battle.isBattleOver)
        }
    }

    private var heroId: String {
        GameContent.heroes[0].id
    }
}
