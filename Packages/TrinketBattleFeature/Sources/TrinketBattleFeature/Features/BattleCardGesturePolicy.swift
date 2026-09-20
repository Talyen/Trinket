import CoreGraphics

/// Card-gesture policy for the battle hand: tap-vs-drag classification,
/// spatial play commitment, deny resistance, and held tilt. Lives next to the
/// `BattleAbilityCardView` gesture state machine that consumes it; pure
/// card geometry stays in `BattleHandLayout`.
enum BattleCardGesturePolicy {
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 10
    private static let denyOvershootFactor: CGFloat = 1.8
    private static let denyWidthDamp: CGFloat = 0.72

    static func exceedsTapSlop(
        translation: CGSize,
        minimumDistance: CGFloat = dragMinimumDistance,
    ) -> Bool {
        hypot(translation.width, translation.height) >= minimumDistance
    }

    static func isTapGesture(
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance,
    ) -> Bool {
        guard !didExceedTapSlop else { return false }
        return !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

    static func shouldPlay(
        translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
    ) -> Bool {
        guard isPlayable else { return false }
        let upwardDistance = -translation.height
        return upwardDistance >= threshold
            && upwardDistance > abs(translation.width)
    }

    static func presentationTranslation(
        _ translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
    ) -> CGSize {
        guard !isPlayable, translation.height < 0 else { return translation }
        let upwardDistance = -translation.height
        guard upwardDistance > threshold else { return translation }
        let overshoot = upwardDistance - threshold
        let resistedOvershoot = overshoot * threshold / (threshold + overshoot * denyOvershootFactor)
        return CGSize(
            width: translation.width * denyWidthDamp,
            height: -(threshold + resistedOvershoot),
        )
    }

    static func heldTilt(
        translation: CGSize,
        cardWidth: CGFloat,
        maximumDegrees: Double,
    ) -> Double {
        guard cardWidth > 0 else { return 0 }
        let positionLean = Double(translation.width / cardWidth) * maximumDegrees
        return min(max(positionLean, -maximumDegrees), maximumDegrees)
    }
}
