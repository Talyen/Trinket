import Foundation
import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatFeedbackCanvasItem: Identifiable {
    let item: CombatFeedbackItem
    let text: String

    var id: Int {
        item.id
    }
}

/// One asynchronous renderer per combatant pane. A single display clock and canvas
/// replace the prior independently animated SwiftUI hierarchy while preserving motion.
struct CombatFeedbackCanvasLayer: View {
    let items: [CombatFeedbackCanvasItem]

    var body: some View {
        if !items.isEmpty {
            TimelineView(.animation) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    for item in items {
                        draw(item, at: timeline.date, in: &context, size: size)
                    }
                }
            }
        }
    }

    private func draw(
        _ canvasItem: CombatFeedbackCanvasItem,
        at date: Date,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let item = canvasItem.item
        let recipe = TrinketMotion.Battle.chip(for: item.feedbackClass)
        let state = CombatFeedbackMotionSampler.state(for: item, recipe: recipe, at: date)
        guard state.opacity > 0.001 else { return }

        let style = item.feedbackVisualStyle
        let label = Text(Image(systemName: style.symbolName))
            + Text("  \(canvasItem.text)")
        var resolved = context.resolve(
            label
                .font(recipe.font(for: .headline))
                .foregroundStyle(style.color)
        )
        resolved.shading = .color(style.color)

        let jitterX = CombatFeedbackLayout.horizontalOffset(
            seed: item.spawnSeed,
            jitter: recipe.horizontalJitter
        )
        var layer = context
        layer.opacity = state.opacity
        layer.translateBy(
            x: size.width * 0.5 + CGFloat(state.horizontalOffset) + jitterX,
            y: size.height * 0.5 + CGFloat(state.verticalOffset)
        )
        layer.rotate(by: .degrees(state.rotation))
        layer.scaleBy(x: CGFloat(state.scale), y: CGFloat(state.scale))

        var shadow = resolved
        shadow.shading = .color(TrinketDesign.Colors.Overlay.ink.opacity(0.95))
        layer.draw(shadow, at: CGPoint(x: 0, y: 1.5), anchor: .center)
        layer.draw(resolved, at: .zero, anchor: .center)
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
    var feedbackVisualStyle: Keyword.VisualStyle {
        switch feedbackClass {
        case .heal: .health
        case .resource: .gold
        case .block: .block
        case .dodge: Keyword.dodge.visualStyle
        case .control: .stun
        case .deathsDoor: Keyword.deathsDoor.visualStyle
        case .directDamage, .critical, .dot, .buff: keyword.visualStyle
        }
    }
}
