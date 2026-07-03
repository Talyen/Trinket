import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleSimulatorTests: XCTestCase {
    private lazy var defaultEnemy = GameContent.enemies.first!.combatant
    private lazy var wolfPet = GameContent.pets.first { $0.id == "wolf" }!

    func testSummaryComputesWinRateAndAverages() {
        let hero = GameContent.heroes[2]
        let victory = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy)
        let watcher = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let wall = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])
        let tickLimit = BattleSimulator.run(hero: watcher, pet: observer, enemy: wall, maxTicks: 3)

        let summary = BattleSimulationSummary.summarize([victory, tickLimit])

        XCTAssertEqual(summary.runCount, 2)
        XCTAssertEqual(summary.winCount, 1)
        XCTAssertEqual(summary.tickLimitCount, 1)
        XCTAssertEqual(summary.winRate, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(summary.averageTickCount, 0)
        XCTAssertGreaterThan(summary.averageActionCount, 0)
    }

    func testRunBatchProducesMultipleResults() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy
        )
        let batch = BattleSimulator.runBatch(
            matchups: [matchup],
            options: BattleSimulationOptions(runCount: 3, seed: 42)
        )

        XCTAssertEqual(batch.count, 1)
        XCTAssertEqual(batch[0].results.count, 3)
        XCTAssertEqual(batch[0].summary.runCount, 3)
    }

    func testRecordsEventsDisabled() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsEvents: false)
        )

        XCTAssertTrue(result.events.isEmpty)
        XCTAssertFalse(result.log.isEmpty)
    }

    func testRecordsLogDisabled() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsLog: false)
        )

        XCTAssertTrue(result.log.isEmpty)
        XCTAssertFalse(result.events.isEmpty)
    }

    func testZeroMaxTicksReturnsTickLimitImmediately() {
        let hero = GameContent.heroes[2]
        let result = BattleSimulator.run(
            hero: hero,
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(maxTicks: 0)
        )

        XCTAssertEqual(result.outcome, .tickLimit)
        XCTAssertEqual(result.tickCount, 0)
        XCTAssertTrue(result.didHitTickLimit)
    }

    func testMetricsSplitAbilityAndStatusDamage() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42)
        )

        XCTAssertGreaterThan(result.metrics.abilityDamage, 0)
        XCTAssertGreaterThanOrEqual(result.metrics.statusDamage, 0)
        XCTAssertEqual(
            result.metrics.totalDamage,
            result.metrics.abilityDamage + result.metrics.statusDamage
        )
    }

    func testVictoryLogMessage() throws {
        let hero = GameContent.heroes[2]
        let pet = try XCTUnwrap(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try XCTUnwrap(GameContent.enemies.first?.combatant)
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(result.log.contains { $0.text.contains("is defeated.") })
    }

    func testDefeatLogMessage() {
        let hero = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        XCTAssertTrue(result.log.contains { $0.text.contains("Your party has been defeated") })
    }
}
