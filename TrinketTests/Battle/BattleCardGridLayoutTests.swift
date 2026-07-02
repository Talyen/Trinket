import XCTest
@testable import Trinket

final class BattleCardGridLayoutTests: XCTestCase {
    func testTallScreensInsetEnemyWithinPartyRow() {
        let containerSize = CGSize(width: 390, height: 760)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.outerPadding, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.cardSpacing, 12, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.width, 177, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 236, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 342, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 456, accuracy: 0.001)
        assertEnemyInsetRelationships(metrics, in: containerSize)
    }

    func testHeightConstrainedScreensKeepEnemyInsetWhileFillingHeight() {
        let containerSize = CGSize(width: 390, height: 700)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 170, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 226.667, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 328, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 437.333, accuracy: 0.001)
        assertEnemyInsetRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    func testCompactScreensKeepInsetGridWithinContainer() {
        let containerSize = CGSize(width: 320, height: 410)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 97.5, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 130, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 183, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 244, accuracy: 0.001)
        assertEnemyInsetRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    private func assertEnemyInsetRelationships(
        _ metrics: BattleCardGridLayout.Metrics,
        in containerSize: CGSize,
        fillsHeight: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let partyRowWidth = 2 * metrics.partySize.width + metrics.cardSpacing
        let gridHeight = metrics.enemySize.height + metrics.cardSpacing + metrics.partySize.height
        let innerHeight = containerSize.height - 2 * metrics.outerPadding
        let enemySideInset = (partyRowWidth - metrics.enemySize.width) / 2

        XCTAssertEqual(enemySideInset, metrics.cardSpacing, accuracy: 0.001, file: file, line: line)
        if fillsHeight {
            XCTAssertEqual(gridHeight, innerHeight, accuracy: 0.001, file: file, line: line)
        } else {
            XCTAssertLessThanOrEqual(gridHeight, innerHeight + 0.001, file: file, line: line)
        }
        XCTAssertLessThanOrEqual(
            partyRowWidth,
            containerSize.width - 2 * metrics.outerPadding + 0.001,
            file: file,
            line: line
        )
    }
}
