import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatFeedbackCanvasItem: Identifiable {
    let item: CombatFeedbackItem
    let label: CombatFeedbackChipLabel

    var id: Int {
        item.id
    }

    /// Derived for tests and debug tooling.
    var text: String {
        label.displayString
    }
}

struct CombatFeedbackAnimationState: Equatable {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
    var horizontalOffset = 0.0
    var rotation = 0.0
}

enum CombatFeedbackMotionSampler {
    static func state(
        for item: CombatFeedbackItem,
        recipe: CombatFeedbackMotionRecipe,
        at date: Date
    ) -> CombatFeedbackAnimationState {
        let elapsed = max(0, date.timeIntervalSince(item.availableAt))
        let horizontalDrift = horizontalDrift(for: item, recipe: recipe)
        let horizontalSamples = adjustedHorizontalSamples(
            recipe: recipe,
            horizontalDrift: horizontalDrift
        )
        return CombatFeedbackAnimationState(
            opacity: sample(initial: recipe.initialOpacity, keyframes: recipe.opacity, elapsed: elapsed),
            scale: sample(initial: recipe.initialScale, keyframes: recipe.scale, elapsed: elapsed),
            verticalOffset: sample(initial: recipe.initialOffsetY, keyframes: recipe.offsetY, elapsed: elapsed),
            horizontalOffset: sample(
                initial: recipe.initialOffsetX,
                keyframes: horizontalSamples,
                elapsed: elapsed
            ),
            rotation: sample(initial: recipe.initialRotation, keyframes: recipe.rotation, elapsed: elapsed)
        )
    }

    private static func horizontalDrift(
        for item: CombatFeedbackItem,
        recipe: CombatFeedbackMotionRecipe
    ) -> CGFloat {
        let angle = CombatFeedbackLayout.floatAngle(
            seed: item.spawnSeed &+ item.presentationIndex &* 97,
            range: recipe.floatAngleRange
        )
        let verticalTravel = CGFloat(abs(recipe.offsetY.last?.value ?? -48))
        return CombatFeedbackLayout.horizontalDrift(
            angleDegrees: angle,
            verticalTravel: verticalTravel
        )
    }

    private static func adjustedHorizontalSamples(
        recipe: CombatFeedbackMotionRecipe,
        horizontalDrift: CGFloat
    ) -> [CombatFeedbackKeyframeSample] {
        let source = recipe.offsetX.isEmpty
            ? recipe.offsetY.map {
                CombatFeedbackKeyframeSample(
                    value: recipe.initialOffsetX,
                    duration: $0.duration,
                    usesSpring: $0.usesSpring
                )
            }
            : recipe.offsetX
        let driftFractions = [0.0, 0.62, 1.0]
        return source.enumerated().map { index, keyframe in
            CombatFeedbackKeyframeSample(
                value: keyframe.value + Double(horizontalDrift) * driftFractions[min(index, 2)],
                duration: keyframe.duration,
                usesSpring: keyframe.usesSpring
            )
        }
    }

    private static func sample(
        initial: Double,
        keyframes: [CombatFeedbackKeyframeSample],
        elapsed: TimeInterval
    ) -> Double {
        var startTime: TimeInterval = 0
        var startValue = initial
        for keyframe in keyframes {
            let endTime = startTime + keyframe.duration
            if elapsed <= endTime {
                let rawProgress = keyframe.duration > 0
                    ? (elapsed - startTime) / keyframe.duration
                    : 1
                let progress = min(max(rawProgress, 0), 1)
                let eased = keyframe.usesSpring
                    ? 1 - pow(1 - progress, 3)
                    : progress * progress * (3 - 2 * progress)
                return startValue + (keyframe.value - startValue) * eased
            }
            startTime = endTime
            startValue = keyframe.value
        }
        return keyframes.last?.value ?? initial
    }
}

extension CombatFeedbackItem {
    /// Primary (trailing) visual style for the chip. Dual-icon chips expose the
    /// subject keyword / role via `chipPresentation` instead.
    var feedbackVisualStyle: Keyword.VisualStyle {
        chipPresentation.trailingTint
    }
}
