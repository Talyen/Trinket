import CoreGraphics
import TrinketContent
import TrinketFeatureSupport

enum BattleCoordinateSpace {
    /// Shared battle-field space for hand → cast presentation handoff.
    static let field = "trinket.battle.field"
}

/// Fan layout metrics for the battle ability hand.
///
/// Keeps GeometryReader math out of the view layer while preserving the
/// overlapping 3:4 card fan (no first-party SwiftUI card-fan API).
enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 220
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.45
    static let horizontalInset: CGFloat = 20
    /// Horizontal stride between consecutive cards as a fraction of card width.
    static let maxOverlapRatio: CGFloat = 0.45
    /// Degrees of fan rotation between adjacent cards.
    static let fanAngleStep: CGFloat = 9
    /// Extra drop for outer cards in the fan.
    static let fanLiftStep: CGFloat = 10
    /// Lifts the hand band off the bottom edge for better card visibility.
    static let bottomRise: CGFloat = 30
    /// Drag-up distance required to play a card (1:1 with finger until release).
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 12
    static let playArmReleaseRatio: CGFloat = 0.72
    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
    }

    static func metrics(
        containerWidth: CGFloat,
        cardCount: Int,
        configuration: BattleHandMotionConfiguration = .init()
    ) -> Metrics {
        let cardWidth = min(
            configuration.maxCardWidth,
            max(configuration.minCardWidth, containerWidth * configuration.widthRatio)
        )
        let cardHeight = cardWidth * configuration.aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * configuration.maxOverlapRatio,
                (containerWidth - cardWidth - configuration.horizontalInset * 2) / CGFloat(cardCount - 1)
            )
            : 0
        let totalWidth = cardWidth + overlap * CGFloat(max(cardCount - 1, 0))
        let startX = (containerWidth - totalWidth) / 2
        return Metrics(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            overlap: overlap,
            startX: startX
        )
    }

    static func cardOffsetX(index: Int, metrics: Metrics, containerWidth: CGFloat) -> CGFloat {
        metrics.startX + CGFloat(index) * metrics.overlap - containerWidth / 2 + metrics.cardWidth / 2
    }

    static func restingCenter(
        index: Int,
        metrics: Metrics,
        cardCount: Int,
        containerFrame: CGRect,
        configuration: BattleHandMotionConfiguration = .init()
    ) -> CGPoint {
        let baseOffsetY = metrics.cardHeight * configuration.restingYFraction
            + restingOffsetY(
                index: index,
                cardCount: cardCount,
                fanLiftStep: configuration.fanLiftStep
            )
        return CGPoint(
            x: containerFrame.midX + cardOffsetX(
                index: index,
                metrics: metrics,
                containerWidth: containerFrame.width
            ),
            y: containerFrame.maxY - configuration.bottomRise - metrics.cardHeight / 2 + baseOffsetY
        )
    }

    /// Converts the card's direct-manipulation translation into the exact
    /// battle-space point where a successful play effect begins.
    static func releaseCenter(restingCenter: CGPoint, dragTranslation: CGSize) -> CGPoint {
        CGPoint(
            x: restingCenter.x + dragTranslation.width,
            y: restingCenter.y + dragTranslation.height
        )
    }

    static func rotation(
        index: Int,
        cardCount: Int,
        fanAngleStep: CGFloat = Self.fanAngleStep
    ) -> CGFloat {
        guard cardCount > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanAngleStep
    }

    static func restingOffsetY(
        index: Int,
        cardCount: Int,
        fanLiftStep: CGFloat = Self.fanLiftStep
    ) -> CGFloat {
        abs(CGFloat(index) - CGFloat(cardCount - 1) / 2) * fanLiftStep
    }

    /// True once finger travel leaves the tap slop band (used so returning a
    /// dragged card to the hand does not count as a tap).
    static func exceedsTapSlop(
        translation: CGSize,
        minimumDistance: CGFloat = dragMinimumDistance
    ) -> Bool {
        abs(translation.width) >= minimumDistance
            || abs(translation.height) >= minimumDistance
    }

    /// Ability detail opens only for presses that never left the tap slop.
    static func isTapGesture(
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance
    ) -> Bool {
        guard !didExceedTapSlop else { return false }
        return !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

    /// A stationary long press is reserved for opening card details. Once the
    /// card leaves the slop band, the existing drag interaction owns the touch.
    static func shouldOpenAbilityDetail(
        didRecognizeLongPress: Bool,
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance
    ) -> Bool {
        didRecognizeLongPress
            && !didExceedTapSlop
            && !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

    static func shouldPlay(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold
    ) -> Bool {
        guard isPlayable else { return false }
        let release = predictedEndTranslation.height < translation.height
            ? predictedEndTranslation
            : translation
        let upwardDistance = -release.height
        return upwardDistance >= threshold
            && upwardDistance > abs(release.width)
    }

    /// Direct-manipulation arming uses the live translation only. Predicted
    /// end translation is intentionally reserved for release intent/momentum,
    /// so the readiness state does not flicker during a held drag.
    static func isPlayArmed(
        translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold
    ) -> Bool {
        guard isPlayable else { return false }
        let upwardDistance = -translation.height
        return upwardDistance >= threshold
            && upwardDistance > abs(translation.width)
    }

    /// Hysteresis keeps the readiness ring stable around the threshold.
    static func shouldRemainPlayArmed(
        translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
        playArmReleaseRatio: CGFloat = Self.playArmReleaseRatio,
        armedHorizontalAllowance: CGFloat = 0.72,
        currentlyArmed: Bool
    ) -> Bool {
        guard isPlayable else { return false }
        let upwardDistance = -translation.height
        let releaseThreshold = threshold * playArmReleaseRatio
        let horizontalAllowance = currentlyArmed ? armedHorizontalAllowance : 1.0
        return upwardDistance >= (currentlyArmed ? releaseThreshold : threshold)
            && upwardDistance > abs(translation.width) * horizontalAllowance
    }

    /// Keeps invalid upward drags responsive while progressively resisting the
    /// part of the gesture that would otherwise cross the play boundary.
    static func presentationTranslation(
        _ translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
        denyOvershootFactor: CGFloat = 1.8,
        denyWidthDamp: CGFloat = 0.72
    ) -> CGSize {
        guard !isPlayable, translation.height < 0 else { return translation }
        let upwardDistance = -translation.height
        guard upwardDistance > threshold else { return translation }
        let overshoot = upwardDistance - threshold
        let resistedOvershoot = overshoot * threshold / (threshold + overshoot * denyOvershootFactor)
        return CGSize(
            width: translation.width * denyWidthDamp,
            height: -(threshold + resistedOvershoot)
        )
    }

    static func heldTilt(
        translation: CGSize,
        predictedEndTranslation _: CGSize,
        cardWidth: CGFloat,
        maximumDegrees: Double
    ) -> Double {
        guard cardWidth > 0 else { return 0 }
        let positionLean = Double(translation.width / cardWidth) * maximumDegrees
        return min(max(positionLean, -maximumDegrees), maximumDegrees)
    }
}
