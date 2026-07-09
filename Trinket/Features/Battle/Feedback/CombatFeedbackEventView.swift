import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatFeedbackEventView: View {
    let item: CombatFeedbackItem
    let stackIndex: Int
    let reduceMotion: Bool

    @State private var rmOpacity = 0.0

    private var recipe: CombatFeedbackMotionRecipe {
        item.recipe
    }

    private var jitterX: CGFloat {
        guard !reduceMotion else { return 0 }
        return CombatFeedbackLayout.horizontalOffset(
            seed: item.spawnSeed,
            jitter: recipe.horizontalJitter
        )
    }

    private var stackY: CGFloat {
        CombatFeedbackLayout.stackOffset(index: stackIndex, spacing: recipe.stackSpacing)
    }

    var body: some View {
        if reduceMotion {
            feedbackLabel
                .opacity(rmOpacity)
                .offset(y: stackY)
                .task(id: item.id) {
                    let clock = SuspendingClock()
                    withAnimation(.easeOut(duration: CombatFeedbackTiming.reduceMotionFadeIn)) {
                        rmOpacity = 1.0
                    }
                    let hold = max(
                        0.05,
                        item.lifetime
                            - CombatFeedbackTiming.reduceMotionFadeIn
                            - CombatFeedbackTiming.reduceMotionFadeOut
                    )
                    try? await clock.sleep(for: .seconds(hold), tolerance: .milliseconds(25))
                    withAnimation(.easeOut(duration: CombatFeedbackTiming.reduceMotionFadeOut)) {
                        rmOpacity = 0.0
                    }
                }
        } else {
            animatedChip
        }
    }

    private var animatedChip: some View {
        let scale = recipe.scale
        let opacity = recipe.opacity
        let offsetY = recipe.offsetY
        let offsetX = recipe.offsetX
        let rotation = recipe.rotation

        return KeyframeAnimator(
            initialValue: CombatFeedbackAnimationState(),
            trigger: item.id
        ) { state in
            feedbackLabel
                .scaleEffect(state.scale)
                .opacity(state.opacity)
                .rotationEffect(.degrees(state.rotation))
                .offset(
                    x: state.horizontalOffset + jitterX,
                    y: state.verticalOffset + stackY
                )
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                SpringKeyframe(scale[safe: 0]?.value ?? 1.1, duration: scale[safe: 0]?.duration ?? 0.14)
                SpringKeyframe(scale[safe: 1]?.value ?? 1.0, duration: scale[safe: 1]?.duration ?? 0.22)
                SpringKeyframe(scale[safe: 2]?.value ?? 0.98, duration: scale[safe: 2]?.duration ?? 0.5)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(opacity[safe: 0]?.value ?? 1.0, duration: opacity[safe: 0]?.duration ?? 0.16)
                CubicKeyframe(opacity[safe: 1]?.value ?? 1.0, duration: opacity[safe: 1]?.duration ?? 0.5)
                CubicKeyframe(opacity[safe: 2]?.value ?? 0.0, duration: opacity[safe: 2]?.duration ?? 0.25)
            }
            KeyframeTrack(\.verticalOffset) {
                SpringKeyframe(offsetY[safe: 0]?.value ?? -8, duration: offsetY[safe: 0]?.duration ?? 0.14)
                SpringKeyframe(offsetY[safe: 1]?.value ?? -34, duration: offsetY[safe: 1]?.duration ?? 0.5)
                SpringKeyframe(offsetY[safe: 2]?.value ?? -48, duration: offsetY[safe: 2]?.duration ?? 0.24)
            }
            KeyframeTrack(\.horizontalOffset) {
                SpringKeyframe(offsetX[safe: 0]?.value ?? 0, duration: offsetX[safe: 0]?.duration ?? 0.01)
                SpringKeyframe(offsetX[safe: 1]?.value ?? offsetX[safe: 0]?.value ?? 0, duration: offsetX[safe: 1]?.duration ?? 0.01)
                SpringKeyframe(offsetX[safe: 2]?.value ?? offsetX[safe: 1]?.value ?? 0, duration: offsetX[safe: 2]?.duration ?? 0.01)
            }
            KeyframeTrack(\.rotation) {
                SpringKeyframe(rotation[safe: 0]?.value ?? 0, duration: rotation[safe: 0]?.duration ?? 0.01)
                SpringKeyframe(rotation[safe: 1]?.value ?? 0, duration: rotation[safe: 1]?.duration ?? 0.01)
                SpringKeyframe(rotation[safe: 2]?.value ?? 0, duration: rotation[safe: 2]?.duration ?? 0.01)
            }
        }
    }

    private var feedbackLabel: some View {
        let style = item.feedbackVisualStyle
        return HStack(spacing: recipe.chrome == .compact ? 4 : 6) {
            Image(systemName: style.symbolName)
                .font(.system(size: max(11, recipe.fontSize - 4), weight: .bold))
                .modifier(SymbolBounceModifier(
                    enabled: recipe.bouncesSymbol && !reduceMotion,
                    trigger: item.id
                ))

            VStack(alignment: .leading, spacing: 0) {
                Text(item.text)
                    .font(recipe.font)
                    .contentTransition(.numericText())

                if recipe.showsSecondaryCaption, let secondary = item.secondaryText {
                    Text(secondary)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .opacity(0.9)
                }
            }
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .trinketGlassChip(recipe.chrome)
    }

    private var chipHorizontalPadding: CGFloat {
        switch recipe.chrome {
        case .standard: return 12
        case .compact: return 8
        case .emphasis: return 14
        case .utility: return 10
        }
    }

    private var chipVerticalPadding: CGFloat {
        switch recipe.chrome {
        case .standard: return 8
        case .compact: return 5
        case .emphasis: return 9
        case .utility: return 6
        }
    }
}

struct CombatFeedbackAnimationState {
    var opacity = 1.0
    var scale = 1.0
    var verticalOffset = 0.0
    var horizontalOffset = 0.0
    var rotation = 0.0
}

private struct SymbolBounceModifier: ViewModifier {
    let enabled: Bool
    let trigger: Int

    func body(content: Content) -> some View {
        if enabled {
            content.symbolEffect(.bounce, value: trigger)
        } else {
            content
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension CombatFeedbackItem {
    var feedbackVisualStyle: Keyword.VisualStyle {
        switch feedbackClass {
        case .heal:
            return .health
        case .resource:
            return .gold
        case .block:
            return .block
        case .dodge:
            return Keyword.dodge.visualStyle
        case .control:
            return .stun
        case .deathsDoor:
            return Keyword.deathsDoor.visualStyle
        case .directDamage, .critical, .dot, .buff:
            return keyword.visualStyle
        }
    }
}
