import CoreGraphics
import Testing
import TrinketDesignSystem
@testable import Trinket

struct BattleCardGridLayoutTests {
    @Test func compactScreensScaleWithoutNegativeSizes() {
        let containerSize = CGSize(width: 320, height: 410)
        let metrics = BattleCardGridLayout.metrics(in: containerSize)

        #expect(metrics.handReservedHeight == BattleCardGridLayout.handReservedHeight)
        #expect(metrics.enemySize.width <= containerSize.width * BattleCardGridLayout.combatantScale + 0.001)
        #expect(metrics.enemySize.width >= 0)
        #expect(metrics.enemySize.height >= 0)
        #expect(metrics.partySize.width >= 0)
        #expect(metrics.partySize.height >= 0)
        assertRelationships(metrics, in: containerSize)
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
    @Test(arguments: [
        (width: CGFloat(390), cardCount: 1),
        (width: CGFloat(375), cardCount: 5),
        (width: CGFloat(390), cardCount: 5),
        (width: CGFloat(430), cardCount: 5)
    ])
    func handMetricsClampAndSpanAcrossPhoneWidths(width: CGFloat, cardCount: Int) {
        let metrics = BattleHandLayout.metrics(containerWidth: width, cardCount: cardCount)
        #expect(metrics.cardWidth >= BattleHandLayout.minCardWidth)
        #expect(metrics.cardWidth <= BattleHandLayout.maxCardWidth)
        #expect(abs(metrics.cardHeight / metrics.cardWidth - BattleHandLayout.aspectRatio) < 0.001)

        if cardCount == 1 {
            #expect(abs(metrics.overlap) < 0.001)
            let offset = BattleHandLayout.cardOffsetX(index: 0, metrics: metrics, containerWidth: width)
            #expect(abs(offset) < 0.001)
        } else {
            let span = metrics.cardWidth + metrics.overlap * CGFloat(cardCount - 1)
            #expect(metrics.overlap > 0)
            #expect(span <= width - BattleHandLayout.horizontalInset * 2 + 0.001)
        }

        // Symmetric fan geometry is owned by the 5-card case; assert once on a mid phone width.
        if width == 390, cardCount == 5 {
            #expect(BattleHandLayout.restingOffsetY(index: 2, cardCount: cardCount) == 0)
            #expect(BattleHandLayout.restingOffsetY(index: 0, cardCount: cardCount)
                > BattleHandLayout.restingOffsetY(index: 1, cardCount: cardCount))
            let rotations = (0 ..< cardCount).map { BattleHandLayout.rotation(index: $0, cardCount: cardCount) }
            #expect(rotations[2] == 0)
            #expect(rotations[0] == -rotations[4])
            #expect(rotations[1] == -rotations[3])
            #expect(rotations[0] < rotations[1])
            #expect(rotations[1] < rotations[2])
        }
    }

    @Test(arguments: [
        (
            translation: CGSize(width: 8, height: -84),
            predicted: CGSize(width: 10, height: -120),
            isPlayable: true,
            shouldPlay: true
        ),
        (
            translation: CGSize(width: 4, height: -55),
            predicted: CGSize(width: 7, height: -105),
            isPlayable: true,
            shouldPlay: true
        ),
        (
            translation: CGSize(width: 120, height: -90),
            predicted: CGSize(width: 170, height: -110),
            isPlayable: true,
            shouldPlay: false
        ),
        (
            translation: CGSize(width: 0, height: 120),
            predicted: CGSize(width: 0, height: 180),
            isPlayable: true,
            shouldPlay: false
        ),
        (
            translation: CGSize(width: 0, height: -120),
            predicted: CGSize(width: 0, height: -180),
            isPlayable: false,
            shouldPlay: false
        )
    ])
    func shouldPlayGestureMatrix(
        translation: CGSize,
        predicted: CGSize,
        isPlayable: Bool,
        shouldPlay: Bool
    ) {
        #expect(
            BattleHandLayout.shouldPlay(
                translation: translation,
                predictedEndTranslation: predicted,
                isPlayable: isPlayable
            ) == shouldPlay
        )
    }

    @Test func playZoneArmingUsesActualTranslationUntilDirectionalThreshold() {
        // Predicted release is intentionally ignored while the finger is held:
        // a fast flick can commit on release, but cannot prematurely arm the card.
        #expect(!BattleHandLayout.isPlayArmed(
            translation: CGSize(width: 0, height: -55),
            isPlayable: true
        ))
        #expect(BattleHandLayout.isPlayArmed(
            translation: CGSize(width: 0, height: -80),
            isPlayable: true
        ))
        #expect(!BattleHandLayout.isPlayArmed(
            translation: CGSize(width: 120, height: -100),
            isPlayable: true
        ))
        #expect(!BattleHandLayout.isPlayArmed(
            translation: CGSize(width: 0, height: -120),
            isPlayable: false
        ))
    }

    @Test func armedPlayZoneUsesHysteresisWhenFingerMovesBackTowardBoundary() {
        // The exit band is 72% of the entry threshold, preventing flicker while
        // a held card jitters near the play boundary.
        #expect(BattleHandLayout.shouldRemainPlayArmed(
            translation: CGSize(width: 0, height: -60),
            isPlayable: true,
            threshold: 80,
            currentlyArmed: true
        ))
        #expect(!BattleHandLayout.shouldRemainPlayArmed(
            translation: CGSize(width: 0, height: -57),
            isPlayable: true,
            threshold: 80,
            currentlyArmed: true
        ))
        #expect(!BattleHandLayout.shouldRemainPlayArmed(
            translation: CGSize(width: 0, height: -79),
            isPlayable: true,
            threshold: 80,
            currentlyArmed: false
        ))
        #expect(!BattleHandLayout.shouldRemainPlayArmed(
            translation: CGSize(width: 0, height: -90),
            isPlayable: false,
            threshold: 80,
            currentlyArmed: true
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

    @Test func configurationOverridesFanAndDenyResistDefaults() {
        var configuration = BattleHandMotionConfiguration()
        configuration.fanAngleStep = 4
        configuration.fanLiftStep = 3
        configuration.denyOvershootFactor = 3.0
        configuration.denyWidthDamp = 0.5

        let rotations = (0 ..< 5).map {
            BattleHandLayout.rotation(index: $0, cardCount: 5, fanAngleStep: configuration.fanAngleStep)
        }
        #expect(rotations[0] == -8)
        #expect(rotations[2] == 0)
        #expect(rotations[4] == 8)
        #expect(
            BattleHandLayout.restingOffsetY(
                index: 0,
                cardCount: 5,
                fanLiftStep: configuration.fanLiftStep
            ) == 6
        )

        let resisted = BattleHandLayout.presentationTranslation(
            CGSize(width: 40, height: -180),
            isPlayable: false,
            threshold: 80,
            denyOvershootFactor: configuration.denyOvershootFactor,
            denyWidthDamp: configuration.denyWidthDamp
        )
        let defaultResisted = BattleHandLayout.presentationTranslation(
            CGSize(width: 40, height: -180),
            isPlayable: false
        )
        #expect(abs(resisted.width) < abs(defaultResisted.width))
        #expect(resisted.height > defaultResisted.height)
    }

    @Test func defaultConfigurationMatchesLayoutConstants() {
        let configuration = BattleHandMotionConfiguration()
        #expect(configuration.minCardWidth == BattleHandLayout.minCardWidth)
        #expect(configuration.maxCardWidth == BattleHandLayout.maxCardWidth)
        #expect(configuration.fanAngleStep == BattleHandLayout.fanAngleStep)
        #expect(configuration.playDragThreshold == BattleHandLayout.playDragThreshold)
        #expect(configuration.playArmReleaseRatio == BattleHandLayout.playArmReleaseRatio)
        #expect(abs(configuration.cardHeldScale - TrinketMotion.Battle.cardHeldScale) < 0.0001)
    }

    @Test func releaseCenterMatchesRestingPlusDragTranslation() {
        // Cast handoff uses this math instead of a live geometry probe so drag
        // frames do not double-invalidate via onGeometryChange.
        let resting = CGPoint(x: 180, y: 640)
        let drag = CGSize(width: 24, height: -96)
        let center = BattleHandLayout.releaseCenter(
            restingCenter: resting,
            dragTranslation: drag
        )
        #expect(center.x == resting.x + drag.width)
        #expect(center.y == resting.y + drag.height)

        let zeroDrag = BattleHandLayout.releaseCenter(
            restingCenter: resting,
            dragTranslation: .zero
        )
        #expect(zeroDrag == resting)
    }

    @Test func tapGestureIgnoresDragReturnNearRestingPosition() {
        // A press that never leaves slop opens ability detail.
        #expect(BattleHandLayout.isTapGesture(
            translation: CGSize(width: 4, height: -3),
            didExceedTapSlop: false
        ))
        // Once the finger left slop, putting the card back down is not a tap.
        #expect(!BattleHandLayout.isTapGesture(
            translation: CGSize(width: 2, height: -1),
            didExceedTapSlop: true
        ))
        #expect(BattleHandLayout.exceedsTapSlop(
            translation: CGSize(width: 0, height: -12)
        ))
        #expect(!BattleHandLayout.exceedsTapSlop(
            translation: CGSize(width: 5, height: -5)
        ))
    }

    @Test func combatantTapSuppressionGraceCoversFingerUpRace() {
        // Long enough to outlast the same-touch Button activation after a hand
        // drag ends over a combatant pane; short enough not to feel sticky.
        #expect(BattleHandLayout.combatantTapSuppressionGrace >= 0.1)
        #expect(BattleHandLayout.combatantTapSuppressionGrace <= 0.3)
    }
}
