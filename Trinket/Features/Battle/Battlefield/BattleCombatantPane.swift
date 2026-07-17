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
    let hapticsEnabled: Bool
    let cinematicNamespace: Namespace.ID
    let onCombatantTap: () -> Void

    private var hasMana: Bool {
        maxMana > 0
    }

    var body: some View {
        Button(action: onCombatantTap) {
            ZStack(alignment: .bottom) {
                CombatantHitReactionLane(
                    combatantID: combatant.id,
                    hapticsEnabled: hapticsEnabled
                ) {
                    artworkPresentation
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Chrome stays masked to the card slot while the reaction portrait
                // recoils/squashes beyond it with its rounded clip.
                ZStack(alignment: .bottom) {
                    ZStack {
                        // Isolated observation leaves: feedback / burst / reaction
                        // updates must not rebuild static pane chrome or BattleView.
                        CombatantKeywordBurstLane(combatantID: combatant.id)
                        CombatantFeedbackLane(
                            combatantID: combatant.id,
                            bottomInset: resourceBarsReservedHeight + 8
                        )
                        CombatantSkillCalloutLane(combatantID: combatant.id)

                        // Invisible source for Ultimate matched-geometry expand from this card.
                        Color.clear
                            .frame(width: 1, height: 1)
                            .matchedGeometryEffect(
                                id: "ultimate-source-\(combatant.id)",
                                in: cinematicNamespace,
                                isSource: true
                            )
                    }

                    resourceBars
                }
                .clipShape(TrinketDesign.cardShape)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
                    .opacity(isDefeated ? 0 : 1)
            }
            .animation(TrinketMotion.Battle.scrim, value: isDefeated)
        }
        .trinketQuietTapButtonStyle()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(combatant.name) card")
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

private struct CombatantHitReactionLane<Artwork: View>: View {
    @Environment(AppState.self) private var appState
    let combatantID: String
    let hapticsEnabled: Bool
    @ViewBuilder let artwork: () -> Artwork

    @State private var latestReactionID = 0

    private var hitReaction: CombatantHitReaction? {
        appState.battle.hitReactionsByTargetID[combatantID]
    }

    var body: some View {
        let reaction = hitReaction
        let reactionID = reaction?.id ?? 0
        let kind = reaction?.kind ?? .none
        let recipe = TrinketMotion.Battle.cardReaction(for: kind)
        let flashColor = reaction?.keyword.visualStyle.color ?? TrinketDesign.Colors.Overlay.paper
        let defaultOffset = CGSize(
            width: CGFloat(recipe.offsetX[safe: 0]?.value ?? 0),
            height: CGFloat(recipe.offsetY[safe: 0]?.value ?? 0)
        )
        let impactOffset = impactOffset(
            for: kind,
            magnitude: abs(defaultOffset.width),
            defaultOffset: defaultOffset
        )
        let isVerticalImpact = impactOffset.height != 0
        let impactScaleX = isVerticalImpact
            ? recipe.scaleY[safe: 0]?.value ?? 1.0
            : recipe.scaleX[safe: 0]?.value ?? 1.0
        let impactScaleY = isVerticalImpact
            ? recipe.scaleX[safe: 0]?.value ?? 1.0
            : recipe.scaleY[safe: 0]?.value ?? 1.0
        let impactDuration = recipe.scaleX[safe: 0]?.duration ?? 0.08
        let recoveryDuration = recipe.scaleX[safe: 1]?.duration ?? 0.16

        KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: reactionID
        ) { state in
            artwork()
                .overlay {
                    flashColor
                        .opacity(state.flashOpacity)
                        .allowsHitTesting(false)
                }
                // Mask travels with the portrait: recoil/squash can leave the
                // card slot without exposing the artwork's rectangular edge.
                .clipShape(TrinketDesign.cardShape)
                .scaleEffect(x: state.scaleX, y: state.scaleY)
                .offset(x: state.offsetX, y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(
                    impactScaleX,
                    duration: impactDuration,
                    spring: .snappy(duration: impactDuration)
                )
                SpringKeyframe(
                    recipe.scaleX[safe: 1]?.value ?? 1.0,
                    duration: recoveryDuration,
                    spring: .bouncy(duration: recoveryDuration)
                )
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(
                    impactScaleY,
                    duration: impactDuration,
                    spring: .snappy(duration: impactDuration)
                )
                SpringKeyframe(
                    recipe.scaleY[safe: 1]?.value ?? 1.0,
                    duration: recoveryDuration,
                    spring: .bouncy(duration: recoveryDuration)
                )
            }
            KeyframeTrack(\.offsetX) {
                SpringKeyframe(
                    impactOffset.width,
                    duration: impactDuration,
                    spring: .snappy(duration: impactDuration)
                )
                SpringKeyframe(
                    recipe.offsetX[safe: 1]?.value ?? 0,
                    duration: recoveryDuration,
                    spring: .bouncy(duration: recoveryDuration)
                )
            }
            KeyframeTrack(\.offsetY) {
                SpringKeyframe(
                    impactOffset.height,
                    duration: impactDuration,
                    spring: .snappy(duration: impactDuration)
                )
                SpringKeyframe(
                    recipe.offsetY[safe: 1]?.value ?? 0,
                    duration: recoveryDuration,
                    spring: .bouncy(duration: recoveryDuration)
                )
            }
            KeyframeTrack(\.flashOpacity) {
                CubicKeyframe(recipe.flashOpacity[safe: 0]?.value ?? 0, duration: recipe.flashOpacity[safe: 0]?.duration ?? 0.06)
                CubicKeyframe(recipe.flashOpacity[safe: 1]?.value ?? 0, duration: recipe.flashOpacity[safe: 1]?.duration ?? 0.16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketSensoryFeedback(
            reactionFeedback(for: reaction?.kind),
            trigger: reaction?.id ?? latestReactionID,
            enabled: hapticsEnabled
        )
        .onChange(of: reaction?.id) { _, reactionID in
            if let reactionID {
                latestReactionID = reactionID
            }
        }
    }

    private func impactOffset(
        for kind: CombatantHitReactionKind,
        magnitude: CGFloat,
        defaultOffset: CGSize
    ) -> CGSize {
        guard kind == .damage || kind == .critical else {
            return defaultOffset
        }
        return CGSize(width: 0, height: -magnitude)
    }

    private func reactionFeedback(for kind: CombatantHitReactionKind?) -> SensoryFeedback {
        switch kind {
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
}

private struct CombatantFeedbackLane: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale
    let combatantID: String
    let bottomInset: CGFloat

    var body: some View {
        // Always-mounted UIKit host; chip publishes arrive via CombatFeedbackChipBridge
        // so chip publishes do not rebuild this lane or BattleView chrome.
        CombatFeedbackRasterSlot(
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        .padding(.horizontal, 8)
        .padding(.bottom, bottomInset)
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}

private struct CombatantKeywordBurstLane: View {
    @Environment(AppState.self) private var appState
    let combatantID: String

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = appState.battle.burstEpoch
        KeywordBurstLayer(requests: appState.battle.keywordBursts(for: combatantID))
    }
}

private struct CombatantSkillCalloutLane: View {
    @Environment(AppState.self) private var appState
    let combatantID: String

    var body: some View {
        if let callout = appState.battle.activeSkillCallout,
           callout.actorID == combatantID {
            SkillCalloutView(callout: callout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
                .allowsHitTesting(false)
        }
    }
}

private struct CardReactionAnimationState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
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
