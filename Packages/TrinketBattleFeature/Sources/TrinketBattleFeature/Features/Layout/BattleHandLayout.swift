import CoreGraphics
import TrinketContent
import TrinketFeatureSupport

enum BattleCoordinateSpace {
    static let field = "trinket.battle.field"
}

enum BattleHandLayout {
    static let minCardWidth: CGFloat = 156
    static let maxCardWidth: CGFloat = 220
    static let aspectRatio: CGFloat = 4.0 / 3.0
    static let widthRatio: CGFloat = 0.45
    static let horizontalInset: CGFloat = 20
    static let maxOverlapRatio: CGFloat = 0.45
    static let fanAngleStep: CGFloat = 9
    static let fanLiftStep: CGFloat = 10
    static let bottomRise: CGFloat = 30
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 12
    static let playArmReleaseRatio: CGFloat = 0.72
    private static let armedHorizontalAllowance: CGFloat = 0.72
    static let restingYFraction: CGFloat = 0.20
    private static let denyOvershootFactor: CGFloat = 1.8
    private static let denyWidthDamp: CGFloat = 0.72
    struct Metrics: Equatable {
        let cardWidth: CGFloat
        let cardHeight: CGFloat
        let overlap: CGFloat
        let startX: CGFloat
    }

    static func metrics(
        containerWidth: CGFloat,
        cardCount: Int
    ) -> Metrics {
        let cardWidth = min(
            maxCardWidth,
            max(minCardWidth, containerWidth * widthRatio)
        )
        let cardHeight = cardWidth * aspectRatio
        let overlap: CGFloat = cardCount > 1
            ? min(
                cardWidth * maxOverlapRatio,
                (containerWidth - cardWidth - horizontalInset * 2) / CGFloat(cardCount - 1)
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
        containerFrame: CGRect
    ) -> CGPoint {
        let baseOffsetY = metrics.cardHeight * restingYFraction
            + restingOffsetY(
                index: index,
                cardCount: cardCount
            )
        return CGPoint(
            x: containerFrame.midX + cardOffsetX(
                index: index,
                metrics: metrics,
                containerWidth: containerFrame.width
            ),
            y: containerFrame.maxY - bottomRise - metrics.cardHeight / 2 + baseOffsetY
        )
    }

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

    static func exceedsTapSlop(
        translation: CGSize,
        minimumDistance: CGFloat = dragMinimumDistance
    ) -> Bool {
        abs(translation.width) >= minimumDistance
            || abs(translation.height) >= minimumDistance
    }

    static func isTapGesture(
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance
    ) -> Bool {
        guard !didExceedTapSlop else { return false }
        return !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

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

    static func shouldRemainPlayArmed(
        translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
        currentlyArmed: Bool
    ) -> Bool {
        guard isPlayable else { return false }
        let upwardDistance = -translation.height
        let releaseThreshold = threshold * playArmReleaseRatio
        let horizontalAllowance = currentlyArmed ? armedHorizontalAllowance : 1.0
        return upwardDistance >= (currentlyArmed ? releaseThreshold : threshold)
            && upwardDistance > abs(translation.width) * horizontalAllowance
    }

    static func presentationTranslation(
        _ translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold
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
