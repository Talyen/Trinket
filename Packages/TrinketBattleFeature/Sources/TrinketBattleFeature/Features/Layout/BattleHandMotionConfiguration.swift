import CoreGraphics
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

/// Tunable hand fan, drag, deal, and spring parameters.
///
/// Defaults match production. Promote dialed-in values back into these defaults
/// (and `TrinketMotion.Battle` where springs / held-feel live) after tuning.
struct BattleHandMotionConfiguration: Equatable {
    // MARK: Fan / sizing

    var minCardWidth: CGFloat = BattleHandLayout.minCardWidth
    var maxCardWidth: CGFloat = BattleHandLayout.maxCardWidth
    var aspectRatio: CGFloat = BattleHandLayout.aspectRatio
    var widthRatio: CGFloat = BattleHandLayout.widthRatio
    var horizontalInset: CGFloat = BattleHandLayout.horizontalInset
    var maxOverlapRatio: CGFloat = BattleHandLayout.maxOverlapRatio
    var fanAngleStep: CGFloat = BattleHandLayout.fanAngleStep
    var fanLiftStep: CGFloat = BattleHandLayout.fanLiftStep
    var bottomRise: CGFloat = BattleHandLayout.bottomRise
    /// Resting vertical tuck as a fraction of card height (`height * fraction`).
    var restingYFraction: CGFloat = 0.20

    // MARK: Play / arm

    var playDragThreshold: CGFloat = BattleHandLayout.playDragThreshold
    var playArmReleaseRatio: CGFloat = BattleHandLayout.playArmReleaseRatio
    var dragMinimumDistance: CGFloat = BattleHandLayout.dragMinimumDistance
    /// Hold duration required to inspect a card without moving it.
    var detailLongPressDuration: TimeInterval = 0.5
    /// When already armed, horizontal drift is allowed up to this factor of upward distance.
    var armedHorizontalAllowance: CGFloat = 0.72

    // MARK: Deny resist

    var denyOvershootFactor: CGFloat = 1.8
    var denyWidthDamp: CGFloat = 0.72

    // MARK: Held feel

    var cardHeldScale: CGFloat = TrinketMotion.Battle.cardHeldScale
    var cardHeldShadowRadius: CGFloat = TrinketMotion.Battle.cardHeldShadowRadius
    var cardHeldShadowY: CGFloat = TrinketMotion.Battle.cardHeldShadowY
    var cardMaximumTiltDegrees: Double = TrinketMotion.Battle.cardMaximumTiltDegrees
    /// Multiplier applied to `cardMaximumTiltDegrees` for horizontal lean while held.
    var tiltLeanMultiplier: Double = 0.65
    var verticalTiltGain: Double = 4
    var verticalTiltClamp: Double = 4
    var perspective: CGFloat = 0.10

    // MARK: Armed visual (production currently haptics-only)

    /// Extra uniform scale while play-armed (0 = no visual change).
    var armedScaleBoost: CGFloat = 0
    /// Brightness boost while play-armed (0 = none).
    var armedBrightness: CGFloat = 0
    var showArmedRing: Bool = false
    var armedRingOpacity: CGFloat = 0.55
    var armedRingLineWidth: CGFloat = 2

    // MARK: Deal / draw

    var dealInsertOffsetX: CGFloat = 120
    var dealInsertOffsetY: CGFloat = 120
    var dealInsertScale: CGFloat = 0.50
    var cardDrawStagger: TimeInterval = TrinketMotion.Battle.cardDrawStagger

    // MARK: Springs (response + damping; mirrors TrinketMotion.Battle)

    var cardPressResponse: Double = 0.16
    var cardPressDamping: Double = 1.0
    var cardLiftResponse: Double = 0.2
    var cardLiftDamping: Double = 1.0
    var cardReturnResponse: Double = 0.38
    var cardReturnDamping: Double = 0.82
    /// How far a tap-play card pops up as a fraction of card height before dissolving.
    var tapLiftHeight: CGFloat = 0.16
    var tapLiftResponse: Double = 0.30
    var tapLiftDamping: Double = 0.68
    /// Pause after the pop before the tap-play dissolve begins (so the lift reads).
    var tapLiftPlayDelay: TimeInterval = 0.18
    var handReflowResponse: Double = 0.34
    var handReflowDamping: Double = 0.92
    var dealResponse: Double = 0.3
    var dealDamping: Double = 0.94

    // MARK: Derived animations

    var cardPress: Animation {
        .spring(response: cardPressResponse, dampingFraction: cardPressDamping)
    }

    var cardLift: Animation {
        .spring(response: cardLiftResponse, dampingFraction: cardLiftDamping)
    }

    var cardReturn: Animation {
        .spring(response: cardReturnResponse, dampingFraction: cardReturnDamping)
    }

    var tapLift: Animation {
        .spring(response: tapLiftResponse, dampingFraction: tapLiftDamping)
    }

    var handReflow: Animation {
        .spring(response: handReflowResponse, dampingFraction: handReflowDamping)
    }

    var deal: Animation {
        .spring(response: dealResponse, dampingFraction: dealDamping)
    }

    var effectiveHeldTiltDegrees: Double {
        cardMaximumTiltDegrees * tiltLeanMultiplier
    }

    // MARK: Explicit Equatable

    /// Explicit implementation: auto-synthesis over 30+ properties generates a single
    /// boolean conjunction the Swift type-checker spends >400ms solving. Split helpers
    /// keep each function under the cyclomatic-complexity limit while preserving O(1) checks.
    static func == (lhs: Self, rhs: Self) -> Bool {
        layoutFieldsEqual(lhs, rhs)
            && interactionFieldsEqual(lhs, rhs)
            && visualFieldsEqual(lhs, rhs)
            && cardSpringFieldsEqual(lhs, rhs)
            && handSpringFieldsEqual(lhs, rhs)
    }

    private static func layoutFieldsEqual(_ lhs: Self, _ rhs: Self) -> Bool {
        guard lhs.minCardWidth == rhs.minCardWidth else { return false }
        guard lhs.maxCardWidth == rhs.maxCardWidth else { return false }
        guard lhs.aspectRatio == rhs.aspectRatio else { return false }
        guard lhs.widthRatio == rhs.widthRatio else { return false }
        guard lhs.horizontalInset == rhs.horizontalInset else { return false }
        guard lhs.maxOverlapRatio == rhs.maxOverlapRatio else { return false }
        guard lhs.fanAngleStep == rhs.fanAngleStep else { return false }
        guard lhs.fanLiftStep == rhs.fanLiftStep else { return false }
        guard lhs.bottomRise == rhs.bottomRise else { return false }
        guard lhs.restingYFraction == rhs.restingYFraction else { return false }
        return true
    }

    private static func interactionFieldsEqual(_ lhs: Self, _ rhs: Self) -> Bool {
        guard lhs.playDragThreshold == rhs.playDragThreshold else { return false }
        guard lhs.playArmReleaseRatio == rhs.playArmReleaseRatio else { return false }
        guard lhs.dragMinimumDistance == rhs.dragMinimumDistance else { return false }
        guard lhs.detailLongPressDuration == rhs.detailLongPressDuration else { return false }
        guard lhs.armedHorizontalAllowance == rhs.armedHorizontalAllowance else { return false }
        guard lhs.denyOvershootFactor == rhs.denyOvershootFactor else { return false }
        guard lhs.denyWidthDamp == rhs.denyWidthDamp else { return false }
        guard lhs.cardHeldScale == rhs.cardHeldScale else { return false }
        guard lhs.cardHeldShadowRadius == rhs.cardHeldShadowRadius else { return false }
        guard lhs.cardHeldShadowY == rhs.cardHeldShadowY else { return false }
        guard lhs.cardMaximumTiltDegrees == rhs.cardMaximumTiltDegrees else { return false }
        guard lhs.tiltLeanMultiplier == rhs.tiltLeanMultiplier else { return false }
        guard lhs.verticalTiltGain == rhs.verticalTiltGain else { return false }
        guard lhs.verticalTiltClamp == rhs.verticalTiltClamp else { return false }
        guard lhs.perspective == rhs.perspective else { return false }
        return true
    }

    private static func visualFieldsEqual(_ lhs: Self, _ rhs: Self) -> Bool {
        guard lhs.armedScaleBoost == rhs.armedScaleBoost else { return false }
        guard lhs.armedBrightness == rhs.armedBrightness else { return false }
        guard lhs.showArmedRing == rhs.showArmedRing else { return false }
        guard lhs.armedRingOpacity == rhs.armedRingOpacity else { return false }
        guard lhs.armedRingLineWidth == rhs.armedRingLineWidth else { return false }
        guard lhs.dealInsertOffsetX == rhs.dealInsertOffsetX else { return false }
        guard lhs.dealInsertOffsetY == rhs.dealInsertOffsetY else { return false }
        guard lhs.dealInsertScale == rhs.dealInsertScale else { return false }
        guard lhs.cardDrawStagger == rhs.cardDrawStagger else { return false }
        return true
    }

    private static func cardSpringFieldsEqual(_ lhs: Self, _ rhs: Self) -> Bool {
        guard lhs.cardPressResponse == rhs.cardPressResponse else { return false }
        guard lhs.cardPressDamping == rhs.cardPressDamping else { return false }
        guard lhs.cardLiftResponse == rhs.cardLiftResponse else { return false }
        guard lhs.cardLiftDamping == rhs.cardLiftDamping else { return false }
        guard lhs.cardReturnResponse == rhs.cardReturnResponse else { return false }
        guard lhs.cardReturnDamping == rhs.cardReturnDamping else { return false }
        guard lhs.tapLiftHeight == rhs.tapLiftHeight else { return false }
        guard lhs.tapLiftResponse == rhs.tapLiftResponse else { return false }
        guard lhs.tapLiftDamping == rhs.tapLiftDamping else { return false }
        guard lhs.tapLiftPlayDelay == rhs.tapLiftPlayDelay else { return false }
        return true
    }

    private static func handSpringFieldsEqual(_ lhs: Self, _ rhs: Self) -> Bool {
        guard lhs.handReflowResponse == rhs.handReflowResponse else { return false }
        guard lhs.handReflowDamping == rhs.handReflowDamping else { return false }
        guard lhs.dealResponse == rhs.dealResponse else { return false }
        guard lhs.dealDamping == rhs.dealDamping else { return false }
        return true
    }
}
