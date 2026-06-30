import XCTest
@testable import Trinket

/// XCTMeasure regression guards for deterministic battle simulation throughput.
/// Run via `./Scripts/test.sh perf` (deploy/nightly tier only).
final class BattleSimulatorPerformanceTests: XCTestCase {
    private lazy var catalogMatchups = Self.makeCatalogMatchups()
    private lazy var singleBattleOptions = BattleSimulationOptions(
        maxTicks: 100,
        seed: 42,
        recordsEvents: false,
        recordsLog: false
    )
    private lazy var batchOptions = BattleSimulationOptions(
        maxTicks: 100,
        runCount: 5,
        seed: 42,
        recordsEvents: false,
        recordsLog: false
    )

    func testSingleBattleSimulationPerformance() {
        let matchup = catalogMatchups[0]
        let options = singleBattleOptions

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            _ = BattleSimulator.run(matchup, options: options)
        }
    }

    func testBatchBattleSimulationPerformance() {
        let matchups = catalogMatchups
        let options = batchOptions

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            _ = BattleSimulator.runBatch(matchups: matchups, options: options)
        }
    }

    private static func makeCatalogMatchups() -> [BattleMatchup] {
        let wolfPet = GameContent.pets.first { $0.id == "wolf" }!
        let enemies = GameContent.enemies.map(\.combatant)

        return Array(GameContent.heroes.prefix(6).enumerated()).map { index, hero in
            BattleMatchup(
                hero: hero,
                pet: wolfPet,
                enemy: enemies[index % enemies.count]
            )
        }
    }
}
