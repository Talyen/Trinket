import CoreGraphics
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

/// Tunable hand fan, drag, deal, and spring parameters.
///
/// Defaults match production. The DEBUG Hand Motion Lab mutates a copy; promote
/// dialed-in values back into these defaults (and `TrinketMotion.Battle` where
/// springs / held-feel live) after tuning.
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

    // MARK: Experimental / unused by production hand path

    var pickupResponse: Double = 0.2
    var pickupDamping: Double = 1.0
    var readinessResponse: Double = 0.24
    var readinessDamping: Double = 0.94
    var cardCommitResponse: Double = 0.28
    var cardCommitDamping: Double = 0.92
    var impactResponse: Double = 0.18
    var impactDamping: Double = 0.82
    var cardMaximumStretch: CGFloat = TrinketMotion.Battle.cardMaximumStretch

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

    /// Paste-friendly dump of every knob for promoting lab values into production.
    func parameterDump() -> String {
        """
        // Fan / sizing
        minCardWidth: \(fmt(minCardWidth))
        maxCardWidth: \(fmt(maxCardWidth))
        aspectRatio: \(fmt(aspectRatio))
        widthRatio: \(fmt(widthRatio))
        horizontalInset: \(fmt(horizontalInset))
        maxOverlapRatio: \(fmt(maxOverlapRatio))
        fanAngleStep: \(fmt(fanAngleStep))
        fanLiftStep: \(fmt(fanLiftStep))
        bottomRise: \(fmt(bottomRise))
        restingYFraction: \(fmt(restingYFraction))

        // Play / arm
        playDragThreshold: \(fmt(playDragThreshold))
        playArmReleaseRatio: \(fmt(playArmReleaseRatio))
        dragMinimumDistance: \(fmt(dragMinimumDistance)), detailLongPressDuration: \(fmt(detailLongPressDuration))
        armedHorizontalAllowance: \(fmt(armedHorizontalAllowance))

        // Deny resist
        denyOvershootFactor: \(fmt(denyOvershootFactor))
        denyWidthDamp: \(fmt(denyWidthDamp))

        // Held feel
        cardHeldScale: \(fmt(cardHeldScale))
        cardHeldShadowRadius: \(fmt(cardHeldShadowRadius))
        cardHeldShadowY: \(fmt(cardHeldShadowY))
        cardMaximumTiltDegrees: \(fmt(cardMaximumTiltDegrees))
        tiltLeanMultiplier: \(fmt(tiltLeanMultiplier))
        verticalTiltGain: \(fmt(verticalTiltGain))
        verticalTiltClamp: \(fmt(verticalTiltClamp))
        perspective: \(fmt(perspective))

        // Armed visual
        armedScaleBoost: \(fmt(armedScaleBoost))
        armedBrightness: \(fmt(armedBrightness))
        showArmedRing: \(showArmedRing)
        armedRingOpacity: \(fmt(armedRingOpacity))
        armedRingLineWidth: \(fmt(armedRingLineWidth))

        // Deal / draw
        dealInsertOffsetX: \(fmt(dealInsertOffsetX))
        dealInsertOffsetY: \(fmt(dealInsertOffsetY))
        dealInsertScale: \(fmt(dealInsertScale))
        cardDrawStagger: \(fmt(cardDrawStagger))

        // Springs
        cardPress: \(fmt(cardPressResponse)) / \(fmt(cardPressDamping))
        cardLift: \(fmt(cardLiftResponse)) / \(fmt(cardLiftDamping))
        cardReturn: \(fmt(cardReturnResponse)) / \(fmt(cardReturnDamping))
        handReflow: \(fmt(handReflowResponse)) / \(fmt(handReflowDamping))
        deal: \(fmt(dealResponse)) / \(fmt(dealDamping))

        // Experimental
        pickup: \(fmt(pickupResponse)) / \(fmt(pickupDamping))
        readiness: \(fmt(readinessResponse)) / \(fmt(readinessDamping))
        cardCommit: \(fmt(cardCommitResponse)) / \(fmt(cardCommitDamping))
        impact: \(fmt(impactResponse)) / \(fmt(impactDamping))
        cardMaximumStretch: \(fmt(cardMaximumStretch))
        """
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.4g", value)
    }

    private func fmt(_ value: CGFloat) -> String {
        String(format: "%.4g", Double(value))
    }
}
