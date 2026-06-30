import XCTest
@testable import Trinket

final class BattleStateTests: XCTestCase {
    private lazy var defaultEnemy = GameContent.enemies.first!.combatant
    private lazy var wolfPet = GameContent.pets.first { $0.id == "wolf" }!

    func testHeroAndPetActTogetherOnSecondTick() {
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [.bash])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        var battle = BattleState(hero: hero, pet: pet, enemy: defaultEnemy)

        _ = battle.performNextAction()
        let events = battle.performNextAction()
        let abilityActors = events.filter { $0.kind == .ability }.map(\.actorName)

        XCTAssertEqual(abilityActors, ["Hero", "Pet"])
    }

    func testEnemyHealthDecreasesOnHit() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let initial = battle.enemyHealth
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        XCTAssertLessThan(battle.enemyHealth, initial)
    }

    func testEnemyAttackTargetPrefersHigherHealthMember() {
        var battle = BattleState(hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy)
        let target = battle.enemyAttackTarget
        XCTAssertEqual(target.id, heroId)
    }

    func testBurnDealsDamageForTwoTicksThenExpires() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: wolfPet, enemy: defaultEnemy)
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        let firstTick = battle.performNextAction()
        let hasBurnFirst = firstTick.contains { $0.floatingText == "-1 Burn" }
        XCTAssertTrue(hasBurnFirst)
        let secondTick = battle.performNextAction()
        let hasBurnSecond = secondTick.contains { $0.floatingText == "-1 Burn" }
        XCTAssertTrue(hasBurnSecond)
    }

    func testPartyDefeatWhenBothHeroAndPetDie() {
        let fragile = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let helper = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        var battle = BattleState(hero: fragile, pet: helper, enemy: enemy)
        while !battle.isBattleOver {
            _ = battle.performNextAction()
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
            if case .damageOverTime(.poison, _, _) = $0 { return true }
            return false
        }
        XCTAssertTrue(hasPoisonDot)
    }

    func testSerratedEdgeDealsBleedDamageAndDot() {
        let ability = Ability.serratedEdge
        XCTAssertEqual(ability.damageKeyword, .bleed)
        let hasBleedDot = ability.effects.contains {
            if case .damageOverTime(.bleed, _, _) = $0 { return true }
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
        _ = battle.performNextAction()
        _ = battle.performNextAction()
        XCTAssertEqual(battle.gold, 11)
    }

    func testInitialGoldReflectedInEarnedGold() {
        var battle = BattleState(hero: GameContent.heroes[2], pet: wolfPet, enemy: defaultEnemy, initialGold: 5)
        _ = battle.performNextAction()
        _ = battle.performNextAction()
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
        let effect1 = Effect.damageOverTime(.burn, 1, 2)
        let effect2 = Effect.damageOverTime(.poison, 2, 3)
        var battle = BattleState(
            hero: GameContent.heroes[0], pet: wolfPet, enemy: defaultEnemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: effect1, remainingTicks: 2),
                ActiveEffect(id: 2, effect: effect2, remainingTicks: 3)
            ]
        )
        _ = battle.performNextAction()
        let summaries = battle.enemyEffectSummaries
        let burnSummary = summaries.first { $0.keyword == .burn }
        let poisonSummary = summaries.first { $0.keyword == .poison }
        XCTAssertNotNil(burnSummary)
        XCTAssertNotNil(poisonSummary)
    }

    func testPetSkipsActionWhenHeroKillsEnemySameTick() {
        let finisher = Ability(id: "finisher", name: "Finisher", tier: .basic, directDamage: 1)
        let hero = Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, abilities: [finisher])
        let pet = Combatant(id: "pet", name: "Pet", role: .pet, maxHealth: 20, abilities: [.bash])
        let enemy = Combatant(id: "enemy", name: "Enemy", role: .enemy, maxHealth: 1, abilities: [])
        var battle = BattleState(hero: hero, pet: pet, enemy: enemy)

        _ = battle.performNextAction()
        let events = battle.performNextAction()
        let petActions = events.filter { $0.actorName == "Pet" && $0.kind == .ability }

        XCTAssertTrue(battle.isEnemyDefeated)
        XCTAssertTrue(petActions.isEmpty)
    }

    private var heroId: String {
        GameContent.heroes[0].id
    }
}
