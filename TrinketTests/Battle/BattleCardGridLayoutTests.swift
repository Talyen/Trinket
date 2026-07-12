import CoreGraphics
import Testing
@testable import Trinket

struct BattleCardGridLayoutTests {
    @Test(arguments: [CGFloat(375), 390, 430])
    func commonPhoneWidthsUseFullBleedTriptychRatios(width: CGFloat) {
        let containerSize = CGSize(width: width, height: 840)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        #expect(metrics.outerPadding == 0)
        #expect(metrics.cardSpacing == 12)
        #expect(metrics.handReservedHeight == BattleCardGridLayout.handReservedHeight)
        #expect(abs(metrics.enemySize.width - width * BattleCardGridLayout.combatantScale) < 0.001)
        assertRelationships(metrics, in: containerSize)
    }

    @Test func compactScreensScaleWithoutNegativeSizes() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 320, height: 410))

        #expect(metrics.enemySize.width >= 0)
        #expect(metrics.enemySize.height >= 0)
        #expect(metrics.partySize.width >= 0)
        #expect(metrics.partySize.height >= 0)
        assertRelationships(metrics, in: CGSize(width: 320, height: 410))
    }

    @Test func veryShortScreensKeepNonNegativeCardSizes() {
        let metrics = BattleCardGridLayout.metrics(in: CGSize(width: 320, height: 40))

        #expect(metrics.partySize == .zero)
        #expect(metrics.enemySize == .zero)
    }

    private func assertRelationships(
        _ metrics: BattleCardGridLayout.Metrics,
        in containerSize: CGSize,
        location: SourceLocation = #_sourceLocation
    ) {
        let partyRowWidth = 2 * metrics.partySize.width + metrics.cardSpacing
        let gridHeight = metrics.enemySize.height + metrics.cardSpacing + metrics.partySize.height
        let innerHeight = containerSize.height
            - 2 * metrics.outerPadding
            - metrics.handReservedHeight
            + BattleCardGridLayout.handOverlapAllowance

        #expect(
            abs(metrics.enemySize.width - partyRowWidth) < 0.001,
            sourceLocation: location
        )
        if metrics.enemySize.height > 0 {
            #expect(
                abs(metrics.enemySize.width / metrics.enemySize.height - 4.0 / 3.0) < 0.001,
                sourceLocation: location
            )
        }
        if metrics.partySize.height > 0 {
            #expect(
                abs(metrics.partySize.width / metrics.partySize.height - 3.0 / 4.0) < 0.001,
                sourceLocation: location
            )
        }
        #expect(partyRowWidth <= containerSize.width + 0.001, sourceLocation: location)
        #expect(gridHeight <= innerHeight + 0.001, sourceLocation: location)
    }
}

struct BattleHandLayoutTests {
    @Test func singleCardCentersWithinWidthClamps() {
        let metrics = BattleHandLayout.metrics(containerWidth: 390, cardCount: 1)
        #expect(metrics.cardWidth >= BattleHandLayout.minCardWidth)
        #expect(metrics.cardWidth <= BattleHandLayout.maxCardWidth)
        #expect(abs(metrics.cardHeight - metrics.cardWidth * BattleHandLayout.aspectRatio) < 0.001)
        #expect(abs(metrics.overlap) < 0.001)
        let offset = BattleHandLayout.cardOffsetX(index: 0, metrics: metrics, containerWidth: 390)
        #expect(abs(offset) < 0.001)
    }

    @Test func fiveCardsUseSymmetricFan() {
        let width: CGFloat = 390
        let count = 5
        let metrics = BattleHandLayout.metrics(containerWidth: width, cardCount: count)
        let span = metrics.cardWidth + metrics.overlap * CGFloat(count - 1)

        #expect(metrics.overlap > 0)
        #expect(span <= width - BattleHandLayout.horizontalInset * 2 + 0.001)
        #expect((0 ..< count).map { BattleHandLayout.rotation(index: $0, cardCount: count) }
            == [-13, -6.5, 0, 6.5, 13])
        #expect(BattleHandLayout.restingOffsetY(index: 2, cardCount: count) == 0)
        #expect(BattleHandLayout.restingOffsetY(index: 0, cardCount: count)
            > BattleHandLayout.restingOffsetY(index: 1, cardCount: count))
    }

    @Test(arguments: [CGFloat(375), 390, 430])
    func fiveCardFanRespondsAcrossPhoneWidths(width: CGFloat) {
        let metrics = BattleHandLayout.metrics(containerWidth: width, cardCount: 5)
        #expect(metrics.cardWidth >= BattleHandLayout.minCardWidth)
        #expect(metrics.cardWidth <= BattleHandLayout.maxCardWidth)
        #expect(abs(metrics.cardHeight / metrics.cardWidth - 4.0 / 3.0) < 0.001)
        let span = metrics.cardWidth + metrics.overlap * 4
        #expect(span <= width - BattleHandLayout.horizontalInset * 2 + 0.001)
    }

    @Test func upwardReleasePastThresholdPlays() {
        #expect(BattleHandLayout.shouldPlay(
            translation: CGSize(width: 8, height: -84),
            predictedEndTranslation: CGSize(width: 10, height: -120),
            isPlayable: true
        ))
    }

    @Test func projectedUpwardFlickPlaysBeforeTranslationReachesThreshold() {
        #expect(BattleHandLayout.shouldPlay(
            translation: CGSize(width: 4, height: -55),
            predictedEndTranslation: CGSize(width: 7, height: -105),
            isPlayable: true
        ))
    }

    @Test func sidewaysDownwardAndUnplayableReleasesReturn() {
        #expect(!BattleHandLayout.shouldPlay(
            translation: CGSize(width: 120, height: -90),
            predictedEndTranslation: CGSize(width: 170, height: -110),
            isPlayable: true
        ))
        #expect(!BattleHandLayout.shouldPlay(
            translation: CGSize(width: 0, height: 120),
            predictedEndTranslation: CGSize(width: 0, height: 180),
            isPlayable: true
        ))
        #expect(!BattleHandLayout.shouldPlay(
            translation: CGSize(width: 0, height: -120),
            predictedEndTranslation: CGSize(width: 0, height: -180),
            isPlayable: false
        ))
    }

    @Test func unplayableUpwardDragRubberBandsPastThreshold() {
        let below = BattleHandLayout.presentationTranslation(
            CGSize(width: 0, height: -60),
            isPlayable: false
        )
        let beyond = BattleHandLayout.presentationTranslation(
            CGSize(width: 40, height: -180),
            isPlayable: false
        )

        #expect(below.height == -60)
        #expect(beyond.height > -180)
        #expect(abs(beyond.width) < 40)
    }

    @Test func heldTiltIsBoundedAndRespondsToHorizontalDirection() {
        let right = BattleHandLayout.heldTilt(
            translation: CGSize(width: 80, height: 0),
            predictedEndTranslation: CGSize(width: 100, height: 0),
            cardWidth: 180,
            maximumDegrees: 7
        )
        let left = BattleHandLayout.heldTilt(
            translation: CGSize(width: -80, height: 0),
            predictedEndTranslation: CGSize(width: -100, height: 0),
            cardWidth: 180,
            maximumDegrees: 7
        )

        #expect(right > 0)
        #expect(left < 0)
        #expect(right <= 7)
        #expect(left >= -7)
    }
}
