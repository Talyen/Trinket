import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct BattleCombatantPane: View {
    enum HealthBarPlacement {
        case top
        case bottom
    }

    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let healthBarPlacement: HealthBarPlacement
    let items: [CombatFeedbackItem]
    let hitReaction: CombatantHitReaction?
    let keywordBursts: [KeywordBurstRequest]
    let skillCallout: SkillCalloutPresentation?
    let reduceMotion: Bool
    let cinematicNamespace: Namespace.ID
    let onCombatantTap: () -> Void

    private var hasMana: Bool {
        maxMana > 0
    }

    var body: some View {
        Button(action: onCombatantTap) {
            ZStack {
                reactiveArtwork

                healthScrim

                healthBar

                ForEach(keywordBursts) { burst in
                    KeywordBurstView(request: burst, reduceMotion: reduceMotion)
                }

                CombatFeedbackOverlay(
                    items: items,
                    reduceMotion: reduceMotion
                )
                .padding(.horizontal, 8)
                .padding(.bottom, feedbackBottomInset)
                .padding(.top, feedbackTopInset)

                if let skillCallout {
                    SkillCalloutView(callout: skillCallout, reduceMotion: reduceMotion)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                        .allowsHitTesting(false)
                }

                // Invisible source for Ultimate matched-geometry expand from this card.
                Color.clear
                    .frame(width: 1, height: 1)
                    .matchedGeometryEffect(
                        id: "ultimate-source-\(combatant.id)",
                        in: cinematicNamespace,
                        isSource: true
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketCardSurface()
            .contentShape(TrinketDesign.cardShape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(healthText)
            .accessibilityHint("Shows details")
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var feedbackTopInset: CGFloat {
        healthBarPlacement == .top ? 44 : 8
    }

    private var feedbackBottomInset: CGFloat {
        healthBarPlacement == .bottom ? 44 : 12
    }

    @ViewBuilder
    private var reactiveArtwork: some View {
        let reactionID = hitReaction?.id ?? 0
        let kind = hitReaction?.kind ?? .none
        let recipe = TrinketMotion.Battle.cardReaction(for: kind)
        let flashColor = hitReaction?.keyword.visualStyle.color ?? .white

        if reduceMotion {
            artworkLayer
                .overlay {
                    if kind == .damage || kind == .critical || kind == .heal {
                        flashColor.opacity(kind == .heal ? 0.18 : 0.22)
                            .allowsHitTesting(false)
                    }
                }
        } else {
            KeyframeAnimator(
                initialValue: CardReactionAnimationState(),
                trigger: reactionID
            ) { state in
                artworkLayer
                    .scaleEffect(state.scale)
                    .offset(x: state.offsetX)
                    .overlay {
                        flashColor
                            .opacity(state.flashOpacity)
                            .allowsHitTesting(false)
                    }
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(recipe.scale[safe: 0]?.value ?? 1.0, duration: recipe.scale[safe: 0]?.duration ?? 0.08)
                    SpringKeyframe(recipe.scale[safe: 1]?.value ?? 1.0, duration: recipe.scale[safe: 1]?.duration ?? 0.16)
                }
                KeyframeTrack(\.offsetX) {
                    SpringKeyframe(recipe.offsetX[safe: 0]?.value ?? 0, duration: recipe.offsetX[safe: 0]?.duration ?? 0.08)
                    SpringKeyframe(recipe.offsetX[safe: 1]?.value ?? 0, duration: recipe.offsetX[safe: 1]?.duration ?? 0.16)
                }
                KeyframeTrack(\.flashOpacity) {
                    CubicKeyframe(recipe.flashOpacity[safe: 0]?.value ?? 0, duration: recipe.flashOpacity[safe: 0]?.duration ?? 0.06)
                    CubicKeyframe(recipe.flashOpacity[safe: 1]?.value ?? 0, duration: recipe.flashOpacity[safe: 1]?.duration ?? 0.16)
                }
            }
        }
    }

    private var artworkLayer: some View {
        CombatantArtwork(combatant: combatant, variant: .battle)
    }

    private var accessibilityLabel: String {
        "\(combatant.name) card"
    }

    private var healthText: String {
        if hasMana {
            return "\(health)/\(maxHealth) HP \(mana)/\(maxMana) MP"
        }
        return "\(health)/\(maxHealth) HP"
    }

    private var healthBar: some View {
        healthChrome {
            if hasMana {
                HStack(spacing: 4) {
                    CombatHealthBar(
                        health: health,
                        maxHealth: maxHealth,
                        fillColor: combatant.healthBarColor,
                        reduceMotion: reduceMotion
                    )

                    CombatManaBar(
                        mana: mana,
                        maxMana: maxMana
                    )
                }
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            } else {
                CombatHealthBar(
                    health: health,
                    maxHealth: maxHealth,
                    fillColor: combatant.healthBarColor,
                    reduceMotion: reduceMotion
                )
                .accessibilityHidden(true)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
    }

    private var healthScrim: some View {
        healthChrome {
            BattleHealthScrimGradient(
                placement: healthBarPlacement == .top ? .top : .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func healthChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            if healthBarPlacement == .bottom {
                Spacer(minLength: 0)
            }

            content()

            if healthBarPlacement == .top {
                Spacer(minLength: 0)
            }
        }
    }
}

private struct CardReactionAnimationState {
    var scale = 1.0
    var offsetX = 0.0
    var flashOpacity = 0.0
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

struct CombatManaBar: View {
    let mana: Int
    let maxMana: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)

                Capsule()
                    .fill(Keyword.mana.visualStyle.color)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: TrinketDesign.Metrics.statBarHeight)
        .clipShape(Capsule())
    }

    private var fraction: Double {
        guard maxMana > 0 else { return 0 }
        return min(max(Double(mana) / Double(maxMana), 0), 1)
    }
}
