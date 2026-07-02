import XCTest
@testable import Trinket

final class BattleCardGridLayoutTests: XCTestCase {
    func testTallScreensUseSquareEnemyAndAlignedThinGutters() {
        let containerSize = CGSize(width: 390, height: 760)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.outerPadding, 8, accuracy: 0.001)
        XCTAssertEqual(metrics.cardSpacing, 8, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.width, 183, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 244, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 374, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 374, accuracy: 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsWidth: true)
    }

    func testHeightConstrainedScreensStillLetPartyCardsReachSideGutters() {
        let containerSize = CGSize(width: 390, height: 700)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 183, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 244, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 374, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 374, accuracy: 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsWidth: true)
    }

    func testCompactScreensScaleAlignedRowsToFitHeight() {
        let containerSize = CGSize(width: 320, height: 410)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        XCTAssertEqual(metrics.partySize.width, 113.4, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 151.2, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 234.8, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 234.8, accuracy: 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    func testVeryShortScreensKeepNonNegativeCardSizes() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 320, height: 40))

        XCTAssertEqual(metrics.partySize.width, 2.4, accuracy: 0.001)
        XCTAssertEqual(metrics.partySize.height, 3.2, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.width, 12.8, accuracy: 0.001)
        XCTAssertEqual(metrics.enemySize.height, 12.8, accuracy: 0.001)
    }

    private func assertAlignedRowRelationships(
        _ metrics: BattleCardGridLayout.Metrics,
        in containerSize: CGSize,
        fillsWidth: Bool = false,
        fillsHeight: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let partyRowWidth = 2 * metrics.partySize.width + metrics.cardSpacing
        let gridHeight = metrics.enemySize.height + metrics.cardSpacing + metrics.partySize.height
        let innerWidth = containerSize.width - 2 * metrics.outerPadding
        let innerHeight = containerSize.height - 2 * metrics.outerPadding

        XCTAssertEqual(metrics.enemySize.width, partyRowWidth, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(
            metrics.enemySize.width,
            metrics.enemySize.height,
            accuracy: 0.001,
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.partySize.width / metrics.partySize.height,
            3.0 / 4.0,
            accuracy: 0.001,
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(partyRowWidth, innerWidth + 0.001, file: file, line: line)
        XCTAssertLessThanOrEqual(gridHeight, innerHeight + 0.001, file: file, line: line)

        if fillsWidth {
            XCTAssertEqual(partyRowWidth, innerWidth, accuracy: 0.001, file: file, line: line)
        }

        if fillsHeight {
            XCTAssertEqual(gridHeight, innerHeight, accuracy: 0.001, file: file, line: line)
        }
    }
}
