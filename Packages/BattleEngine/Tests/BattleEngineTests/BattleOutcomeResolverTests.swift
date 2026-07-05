import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleOutcomeResolverTests: XCTestCase {
    func testSimultaneousDefeatResolvesAsVictory() {
        XCTAssertEqual(
            BattleOutcomeResolver.resolve(isPartyDefeated: true, isEnemyDefeated: true),
            .victory
        )
    }

    func testPartyDefeatResolvesAsDefeat() {
        XCTAssertEqual(
            BattleOutcomeResolver.resolve(isPartyDefeated: true, isEnemyDefeated: false),
            .defeat
        )
    }

    func testEnemyDefeatResolvesAsVictory() {
        XCTAssertEqual(
            BattleOutcomeResolver.resolve(isPartyDefeated: false, isEnemyDefeated: true),
            .victory
        )
    }

    func testOngoingBattleReturnsNil() {
        XCTAssertNil(
            BattleOutcomeResolver.resolve(isPartyDefeated: false, isEnemyDefeated: false)
        )
    }
}
