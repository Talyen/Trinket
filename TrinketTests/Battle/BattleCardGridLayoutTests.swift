import XCTest
@testable import Trinket

final class BattleCardGridLayoutTests: XCTestCase {
    func testPartyCardsMaximizeToAvailableColumnsOnTallScreens() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 390, height: 760))

        XCTAssertEqual(metrics.partySize.width, 180, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 240, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 367.5, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 490, accuracy: 0.001)
    }

    func testEnemyUsesRemainingHeightWithoutShrinkingPartyCards() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 390, height: 700))

        XCTAssertEqual(metrics.partySize.width, 180, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 240, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 322.5, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 430, accuracy: 0.001)
    }

    func testHeightConstrainedScreensKeepEnemyAtLeastPartyScale() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 320, height: 410))

        XCTAssertEqual(metrics.partySize.width, 142.5, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 190, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 142.5, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 190, accuracy: 0.001)
    }
}
