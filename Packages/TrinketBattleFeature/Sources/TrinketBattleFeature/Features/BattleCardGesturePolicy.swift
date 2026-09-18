import CoreGraphics

/// Card-gesture policy for the battle hand: tap-vs-drag classification,
/// play arming, deny resistance, and held tilt. Lives next to the
/// `BattleAbilityCardView` gesture state machine that consumes it; pure
/// card geometry stays in `BattleHandLayout`.
enum BattleCardGesturePolicy {
    static let playDragThreshold: CGFloat = 80
    static let dragMinimumDistance: CGFloat = 12
    static let playArmReleaseRatio: CGFloat = 0.72
    private static let armedHorizontalAllowance: CGFloat = 0.72
    private static let denyOvershootFactor: CGFloat = 1.8
    private static let denyWidthDamp: CGFloat = 0.72

    static func exceedsTapSlop(
        translation: CGSize,
        minimumDistance: CGFloat = dragMinimumDistance,
    ) -> Bool {
        abs(translation.width) >= minimumDistance
            || abs(translation.height) >= minimumDistance
    }

    static func isTapGesture(
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance,
    ) -> Bool {
        guard !didExceedTapSlop else { return false }
        return !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

    static func shouldOpenAbilityDetail(
        didRecognizeLongPress: Bool,
        translation: CGSize,
        didExceedTapSlop: Bool,
        minimumDistance: CGFloat = dragMinimumDistance,
    ) -> Bool {
        didRecognizeLongPress
            && !didExceedTapSlop
            && !exceedsTapSlop(translation: translation, minimumDistance: minimumDistance)
    }

    static func shouldPlay(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
        currentlyArmed: Bool = false,
    ) -> Bool {
        guard isPlayable else { return false }
        if currentlyArmed {
            return true
        }
        let release = predictedEndTranslation.height < translation.height
            ? predictedEndTranslation
            : translation
        let upwardDistance = -release.height
        return upwardDistance >= threshold
            && upwardDistance > abs(release.width)
    }

    static func shouldRemainPlayArmed(
        translation: CGSize,
        isPlayable: Bool,
        threshold: CGFloat = playDragThreshold,
        currentlyArmed: Bool,
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
        predictedEndTranslation _: CGSize,
        cardWidth: CGFloat,
        maximumDegrees: Double,
    ) -> Double {
        guard cardWidth > 0 else { return 0 }
        let positionLean = Double(translation.width / cardWidth) * maximumDegrees
        return min(max(positionLean, -maximumDegrees), maximumDegrees)
    }
}
