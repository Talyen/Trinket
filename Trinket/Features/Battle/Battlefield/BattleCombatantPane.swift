import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct BattleCombatantPane: View {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let items: [CombatFeedbackItem]
    let hitReaction: CombatantHitReaction?
    let keywordBursts: [KeywordBurstRequest]
    let skillCallout: SkillCalloutPresentation?
    let hapticsEnabled: Bool
    let cinematicNamespace: Namespace.ID
    let onCombatantTap: () -> Void

    @State private var latestReactionID = 0

    private var hasMana: Bool {
        maxMana > 0
    }

    var body: some View {
        Button(action: onCombatantTap) {
            ZStack(alignment: .bottom) {
                ZStack {
                    reactiveArtwork
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .trinketArtworkBlend(.perimeter(into: .canvas))
                        .clipped()

                    KeywordBurstLayer(requests: keywordBursts)

                    CombatFeedbackOverlay(items: items)
                        .padding(.horizontal, 8)
                        .padding(.bottom, resourceBarsReservedHeight + 8)
                        .padding(.top, 8)

                    if let skillCallout {
                        SkillCalloutView(callout: skillCallout)
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
                .clipped()

                resourceBars
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(TrinketDesign.cardShape)
        }
        .trinketQuietTapButtonStyle()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketSensoryFeedback(
            reactionFeedback,
            trigger: hitReaction?.id ?? latestReactionID,
            enabled: hapticsEnabled
        )
        .onChange(of: hitReaction?.id) { _, reactionID in
            if let reactionID {
                latestReactionID = reactionID
            }
        }
        .accessibilityIdentifier("\(combatant.name) card")
    }

    private var reactionFeedback: SensoryFeedback {
        switch hitReaction?.kind {
        case .some(.critical):
            .impact(weight: .heavy)
        case .some(.heal):
            .success
        case .some(.dodge):
            .selection
        case .some(.damage), .some(.block):
            .impact(weight: .light)
        case .some(.none), nil:
            .impact(weight: .light)
        }
    }

    @ViewBuilder
    private var reactiveArtwork: some View {
        let reactionID = hitReaction?.id ?? 0
        let kind = hitReaction?.kind ?? .none
        let recipe = TrinketMotion.Battle.cardReaction(for: kind)
        let flashColor = hitReaction?.keyword.visualStyle.color ?? TrinketDesign.Colors.Overlay.paper

        KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: reactionID
        ) { state in
            artworkPresentation
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var artworkPresentation: some View {
        if isDefeated {
            BattleDissolveArtwork {
                artworkLayer
            }
        } else {
            artworkLayer
        }
    }

    private var isDefeated: Bool {
        health <= 0
    }

    private var artworkLayer: some View {
        CombatantArtwork(combatant: combatant, variant: .battle)
    }

    private var resourceBarsReservedHeight: CGFloat {
        let healthHeight = TrinketDesign.Metrics.battleHealthBarHeight
        guard hasMana else { return healthHeight }
        return healthHeight * 2
    }

    private var resourceBars: some View {
        VStack(spacing: 0) {
            CombatHealthBar(
                health: health,
                maxHealth: maxHealth,
                fillColor: TrinketDesign.Colors.battleHealth,
                style: .battleBorder,
                height: TrinketDesign.Metrics.battleHealthBarHeight
            )

            if hasMana {
                CombatManaBar(mana: mana, maxMana: maxMana)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isDefeated ? 0 : 1)
        .animation(TrinketMotion.Battle.scrim, value: isDefeated)
        .allowsHitTesting(!isDefeated)
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
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(TrinketDesign.Colors.battleHealthTrack)

            Rectangle()
                .fill(Keyword.mana.visualStyle.color)
                .scaleEffect(x: fraction, y: 1, anchor: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: TrinketDesign.Metrics.battleHealthBarHeight)
        .clipShape(Rectangle())
    }

    private var fraction: Double {
        guard maxMana > 0 else { return 0 }
        return min(max(Double(mana) / Double(maxMana), 0), 1)
    }
}
