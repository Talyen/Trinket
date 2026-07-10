import CoreGraphics
import Testing
@testable import Trinket

struct BattleCardGridLayoutTests {
    @Test func tallScreensUseSquareEnemyAndAlignedThinGutters() {
        let containerSize = CGSize(width: 390, height: 760)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        #expect(abs((metrics.outerPadding) - 8) < 0.001)
        #expect(abs((metrics.cardSpacing) - 8) < 0.001)
        #expect(abs((metrics.handReservedHeight) - 230) < 0.001)
        #expect(abs((metrics.partySize.width) - 149.4) < 0.001)
        #expect(abs((metrics.partySize.height) - 199.2) < 0.001)
        #expect(abs((metrics.enemySize.width) - 306.8) < 0.001)
        #expect(abs((metrics.enemySize.height) - 306.8) < 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    @Test func heightConstrainedScreensStillLetPartyCardsReachSideGutters() {
        let containerSize = CGSize(width: 390, height: 700)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        #expect(abs((metrics.partySize.width) - 131.4) < 0.001)
        #expect(abs((metrics.partySize.height) - 175.2) < 0.001)
        #expect(abs((metrics.enemySize.width) - 270.8) < 0.001)
        #expect(abs((metrics.enemySize.height) - 270.8) < 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    @Test func compactScreensScaleAlignedRowsToFitHeight() {
        let containerSize = CGSize(width: 320, height: 410)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        #expect(abs((metrics.partySize.width) - 44.4) < 0.001)
        #expect(abs((metrics.partySize.height) - 59.2) < 0.001)
        #expect(abs((metrics.enemySize.width) - 96.8) < 0.001)
        #expect(abs((metrics.enemySize.height) - 96.8) < 0.001)
        assertAlignedRowRelationships(metrics, in: containerSize, fillsHeight: true)
    }

    @Test func veryShortScreensKeepNonNegativeCardSizes() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 320, height: 40))

        #expect(abs((metrics.partySize.width) - 0) < 0.001)
        #expect(abs((metrics.partySize.height) - 0) < 0.001)
        #expect(abs((metrics.enemySize.width) - 0) < 0.001)
        #expect(abs((metrics.enemySize.height) - 0) < 0.001)
    }

    private func assertAlignedRowRelationships(
        _ metrics: BattleCardGridLayout.Metrics,
        in containerSize: CGSize,
        fillsWidth: Bool = false,
        fillsHeight: Bool = false,
        location: SourceLocation = #_sourceLocation
    ) {
        let partyRowWidth = 2 * metrics.partySize.width + metrics.cardSpacing
        let gridHeight = metrics.enemySize.height + metrics.cardSpacing + metrics.partySize.height
        let innerWidth = containerSize.width - 2 * metrics.outerPadding
        let innerHeight = containerSize.height - 2 * metrics.outerPadding - metrics.handReservedHeight

        #expect(abs((metrics.enemySize.width) - partyRowWidth) < 0.001, sourceLocation: location)
        #expect(
            abs(metrics.enemySize.width - metrics.enemySize.height) < 0.001,
            sourceLocation: location
        )
        #expect(
            abs((metrics.partySize.width / metrics.partySize.height) - (3.0 / 4.0)) < 0.001,
            sourceLocation: location
        )
        #expect(partyRowWidth <= innerWidth + 0.001, sourceLocation: location)
        #expect(gridHeight <= innerHeight + 0.001, sourceLocation: location)

        if fillsWidth {
            #expect(abs(partyRowWidth - innerWidth) < 0.001, sourceLocation: location)
        }

        if fillsHeight {
            #expect(abs(gridHeight - innerHeight) < 0.001, sourceLocation: location)
        }
    }
}
