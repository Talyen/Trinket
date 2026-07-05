import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleOutcomeResolverTests: XCTestCase {
    func testSimultaneousDefeatResolvesAsVictory() {
        XCTAssertEqual(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: true),
            .victory
        )
    }

    func testPartyDefeatResolvesAsDefeat() {
        XCTAssertEqual(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: false),
            .defeat
        )
    }

    func testEnemyDefeatResolvesAsVictory() {
        XCTAssertEqual(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: true),
            .victory
        )
    }

    func testOngoingBattleReturnsNil() {
        XCTAssertNil(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: false)
        )
    }
}
