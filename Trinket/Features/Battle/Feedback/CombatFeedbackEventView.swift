import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatFeedbackEventView: View {
    let item: CombatFeedbackItem
    let role: CombatFeedbackPresentationRole
    let laneIndex: Int
    let textOverride: String?

    @State private var symbolTrigger = false

    init(
        item: CombatFeedbackItem,
        role: CombatFeedbackPresentationRole? = nil,
        laneIndex: Int? = nil,
        textOverride: String? = nil
    ) {
        self.item = item
        self.role = role ?? (item.presentationIndex == 0 ? .headline : .secondary)
        self.laneIndex = laneIndex ?? item.presentationIndex
        self.textOverride = textOverride
    }

    private var recipe: CombatFeedbackMotionRecipe {
        item.recipe
    }

    private var jitterX: CGFloat {
        CombatFeedbackLayout.horizontalOffset(
            seed: item.spawnSeed &+ laneIndex &* 31,
            jitter: recipe.horizontalJitter
        )
    }

    private var stackY: CGFloat {
        CombatFeedbackLayout.presentationOffset(index: laneIndex)
    }

    var body: some View {
        animatedChip
            .task(id: item.id) {
                symbolTrigger.toggle()
            }
    }

    private var animatedChip: some View {
        let scale = recipe.scale
        let opacity = recipe.opacity
        let offsetY = recipe.offsetY
        let offsetX = recipe.offsetX
        let rotation = recipe.rotation

        return KeyframeAnimator(
            initialValue: CombatFeedbackAnimationState(
                opacity: recipe.initialOpacity,
                scale: recipe.initialScale,
                verticalOffset: recipe.initialOffsetY,
                horizontalOffset: recipe.initialOffsetX,
                rotation: recipe.initialRotation
            ),
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

    @ViewBuilder
    private var feedbackLabel: some View {
        if role == .overflow {
            HStack(spacing: 5) {
                Image(systemName: "ellipsis")
                    .font(.callout.weight(.bold))
                Text(textOverride ?? item.text)
                    .font(recipe.font(for: .overflow))
            }
            .foregroundStyle(.secondary)
            .trinketCombatFloatText()
        } else {
            let style = item.feedbackVisualStyle
            HStack(spacing: 6) {
                Image(systemName: style.symbolName)
                    .font(symbolFont)
                    .modifier(SymbolBounceModifier(
                        enabled: recipe.bouncesSymbol,
                        trigger: symbolTrigger
                    ))

                VStack(alignment: .leading, spacing: 0) {
                    Text(textOverride ?? item.text)
                        .font(recipe.font(for: role))
                        .contentTransition(.numericText())

                    if role == .headline,
                       recipe.showsSecondaryCaption,
                       let secondary = item.secondaryText {
                        Text(secondary)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .opacity(0.92)
                    }
                }
            }
            .foregroundStyle(style.color)
            .trinketCombatFloatText()
        }
    }

    private var symbolFont: Font {
        switch role {
        case .headline: .title2.weight(.heavy)
        case .secondary: .headline.weight(.bold)
        case .overflow: .callout.weight(.bold)
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
    let trigger: Bool

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
            .health
        case .resource:
            .gold
        case .block:
            .block
        case .dodge:
            Keyword.dodge.visualStyle
        case .control:
            .stun
        case .deathsDoor:
            Keyword.deathsDoor.visualStyle
        case .directDamage, .critical, .dot, .buff:
            keyword.visualStyle
        }
    }
}
