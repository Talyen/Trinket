import XCTest
@testable import Trinket

final class BattleCardGridLayoutTests: XCTestCase {
    func testTallScreensUseUniformBattlefieldGutters() {
        let containerSize = CGSize(width: 390, height: 760)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.outerPadding, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.cardSpacing, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.width, 177, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 236, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 366, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 488, accuracy: 0.001)
        assertSharedGridRelationships(metrics, in: containerSize)
    }

    func testHeightConstrainedScreensScaleRowsTogether() {
        let containerSize = CGSize(width: 390, height: 700)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 162, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 216, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 336, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 448, accuracy: 0.001)
        assertSharedGridRelationships(metrics, in: containerSize)
    }

    func testCompactScreensKeepSharedGridWithinContainer() {
        let containerSize = CGSize(width: 320, height: 410)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 89.5, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 119.333, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 191, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 254.667, accuracy: 0.001)
        assertSharedGridRelationships(metrics, in: containerSize)
    }

    private func assertSharedGridRelationships(
        _ metrics: BattleCardGridLayout.Metrics,
        in containerSize: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let partyRowWidth = 2 * metrics.partySize.width + metrics.cardSpacing
        let gridHeight = metrics.enemySize.height + metrics.cardSpacing + metrics.partySize.height
        let innerHeight = containerSize.height - 2 * metrics.outerPadding

        XCTAssertEqual(metrics.enemySize.width, partyRowWidth, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(gridHeight, innerHeight, accuracy: 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(
            metrics.enemySize.width,
            containerSize.width - 2 * metrics.outerPadding + 0.001,
            file: file,
            line: line
        )
    }
}
