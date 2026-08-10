import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleCombatantPane: View {
    let combatant: Combatant
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let borderAccentKeyword: Keyword?
    let buffAuraKind: CombatantBuffAuraKind?
    let hapticsEnabled: Bool
    let recoilDirection: CombatantHitRecoilDirection
    let onCombatantTap: () -> Void

    private var hasMana: Bool {
        maxMana > 0
    }

    var body: some View {
        Button(action: onCombatantTap) {
            CombatantAttackLane(
                combatantID: combatant.id,
                aim: TrinketMotion.Battle.attackAim(isPartyMember: recoilDirection == .down)
            ) {
                ZStack(alignment: .bottom) {
                    // Art + resource bars + border share hit reaction; attack lane
                    // wraps the whole chrome so the enemy card lunges as one unit.
                    CombatantHitReactionLane(
                        combatantID: combatant.id,
                        hapticsEnabled: hapticsEnabled,
                        recoilDirection: recoilDirection,
                        borderVisible: !isDefeated,
                        borderAccentKeyword: borderAccentKeyword,
                        buffAuraKind: buffAuraKind
                    ) {
                        ZStack(alignment: .bottom) {
                            artworkPresentation
                            resourceBars
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Bursts / callouts stay masked to the card slot while the
                    // reaction frame (portrait + bars) recoils beyond it.
                    ZStack {
                        // Isolated observation leaves: feedback / burst / reaction
                        // updates must not rebuild static pane chrome or BattleView.
                        CombatantKeywordBurstLane(combatantID: combatant.id)
                        CombatantSkillCalloutLane(combatantID: combatant.id)
                    }
                    .clipShape(TrinketDesign.cardShape)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(TrinketDesign.cardShape)
                .animation(TrinketMotion.Battle.scrim, value: isDefeated)
            }
        }
        .trinketQuietTapButtonStyle()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("\(combatant.name) card")
    }

    @ViewBuilder
    private var artworkPresentation: some View {
        if isDefeated {
            if recoilDirection == .up {
                BattleSliceArtwork {
                    artworkLayer
                }
            } else {
                BattleDissolveArtwork(celebratesDefeat: false) {
                    artworkLayer
                }
            }
        } else {
            CombatantStatusEffectPresentation(keyword: borderAccentKeyword) {
                artworkLayer
            }
        }
    }

    private var isDefeated: Bool {
        health <= 0
    }

    private var artworkLayer: some View {
        CombatantArtwork(combatant: combatant, variant: .battle)
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
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String
    let hapticsEnabled: Bool
    let recoilDirection: CombatantHitRecoilDirection
    let borderVisible: Bool
    let borderAccentKeyword: Keyword?
    let buffAuraKind: CombatantBuffAuraKind?
    @ViewBuilder let artwork: () -> Artwork

    /// Local trigger so KeyframeAnimator always sees a change, even when reaction
    /// storage is ObservationIgnored and only the epoch fence invalidates this lane.
    @State private var playToken = 0
    @State private var activeKind: CombatantHitReactionKind = .none
    @State private var latestReactionID = 0
    /// Bright end of the status border opacity cycle while an accent is active.
    @State private var statusBorderPulseBright = false

    var body: some View {
        // Subscribe to the observation fence (hitReactions storage is ignored).
        // swiftlint:disable:next redundant_discardable_let
        let _ = battleSession.feedback.hitReactionEpoch
        let layout = ReactionLayoutState(
            activeKind: activeKind,
            recoilDirection: recoilDirection
        )

        KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: playToken
        ) { state in
            artwork()
                // Mask travels with the frame (art + bars): recoil/squash can
                // leave the card slot without exposing rectangular edges.
                .clipShape(TrinketDesign.cardShape)
                // Border after clip so the stroke is not half-masked, and rides
                // the same scale/offset as art + bars (whole-card hop).
                .overlay {
                    cardBorder
                        .opacity(borderVisible ? 1 : 0)
                }
                .scaleEffect(x: state.scaleX, y: state.scaleY)
                .rotationEffect(.degrees(state.rotation))
                .offset(x: state.offsetX, y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(
                    layout.impactScaleX,
                    duration: layout.impactDuration,
                    spring: .snappy(duration: layout.impactDuration)
                )
                SpringKeyframe(
                    layout.recipe.scaleX[safe: 1]?.value ?? 1.0,
                    duration: layout.recoveryDuration,
                    spring: .bouncy(duration: layout.recoveryDuration)
                )
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(
                    layout.impactScaleY,
                    duration: layout.impactDuration,
                    spring: .snappy(duration: layout.impactDuration)
                )
                SpringKeyframe(
                    layout.recipe.scaleY[safe: 1]?.value ?? 1.0,
                    duration: layout.recoveryDuration,
                    spring: .bouncy(duration: layout.recoveryDuration)
                )
            }
            KeyframeTrack(\.offsetX) {
                CubicKeyframe(layout.impactOffsetX, duration: layout.impactDuration)
                CubicKeyframe(layout.recoverOffsetX, duration: layout.recoveryDuration)
            }
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(layout.impactOffsetY, duration: layout.impactDuration)
                CubicKeyframe(layout.recoverOffsetY, duration: layout.recoveryDuration)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(
                    layout.recipe.rotation[safe: 0]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 0]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 1]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 1]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 2]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 2]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 3]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 3]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 4]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 4]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 5]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 5]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 6]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 6]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 7]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 7]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 8]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 8]?.duration ?? 0.01
                )
                CubicKeyframe(
                    layout.recipe.rotation[safe: 9]?.value ?? 0,
                    duration: layout.recipe.rotation[safe: 9]?.duration ?? 0.01
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketSensoryFeedback(
            reactionFeedback(for: activeKind == .none ? nil : activeKind),
            trigger: playToken,
            enabled: hapticsEnabled
        )
        .onChange(of: battleSession.feedback.hitReactionEpoch) { _, _ in
            adoptLatestReactionIfNeeded()
        }
        .onAppear {
            syncStatusBorderPulse(isActive: usesStatusBorderPulse)
        }
        .onChange(of: borderAccentKeyword) { _, _ in
            syncStatusBorderPulse(isActive: usesStatusBorderPulse)
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        if usesStatusBorderPulse {
            TrinketDesign.cardShape.strokeBorder(
                borderStrokeColor,
                lineWidth: 1
            )
        } else if let buffAuraKind {
            CombatantBuffAuraBorder(kind: buffAuraKind)
        } else {
            TrinketDesign.cardShape.strokeBorder(
                TrinketDesign.Colors.subtleStroke,
                lineWidth: 1
            )
        }
    }

    /// Stun/freeze use portrait overlays; only Death's Door keeps the pulsing border.
    private var usesStatusBorderPulse: Bool {
        borderAccentKeyword == .deathsDoor
    }

    private var borderStrokeColor: Color {
        guard usesStatusBorderPulse, let borderAccentKeyword else {
            return TrinketDesign.Colors.subtleStroke
        }
        let opacity = statusBorderPulseBright
            ? 1.0
            : TrinketMotion.Battle.statusBorderPulseDimOpacity
        return borderAccentKeyword.visualStyle.color.opacity(opacity)
    }

    private func syncStatusBorderPulse(isActive: Bool) {
        if isActive {
            statusBorderPulseBright = false
            withAnimation(
                TrinketMotion.Battle.statusBorderPulse.repeatForever(autoreverses: true)
            ) {
                statusBorderPulseBright = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                statusBorderPulseBright = false
            }
        }
    }

    private func adoptLatestReactionIfNeeded() {
        guard let reaction = battleSession.feedback.hitReactionsByTargetID[combatantID],
              reaction.id != latestReactionID
        else { return }
        // Install recipe/kind first, then bump the trigger on the next turn so
        // KeyframeAnimator does not start with stale `.none` keyframes (offset 0).
        activeKind = reaction.kind
        latestReactionID = reaction.id
        Task { @MainActor in
            playToken &+= 1
        }
    }

    private func reactionFeedback(for kind: CombatantHitReactionKind?) -> SensoryFeedback {
        switch kind {
        case .some(.critical):
            .impact(weight: .heavy)
        case .some(.heal), .some(.celebrate):
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

private struct CombatantKeywordBurstLane: View {
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String

    var body: some View {
        // swiftlint:disable:next redundant_discardable_let
        let _ = battleSession.feedback.burstEpoch
        KeywordBurstLayer(requests: battleSession.feedback.keywordBursts(for: combatantID))
    }
}

private struct CombatantSkillCalloutLane: View {
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String

    var body: some View {
        if let callout = battleSession.spectacle.activeSkillCallout,
           callout.actorID == combatantID {
            SkillCalloutView(callout: callout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(TrinketDesign.Metrics.sectionHeaderSpacing)
                .allowsHitTesting(false)
        }
    }
}

/// Pre-computes hit-reaction keyframe parameters outside of `body` so each
/// stored property is type-checked individually (O(1)) rather than as a single
/// body expression. Without this helper, the compiler spends ~160ms solving the
/// combined constraint set.
private struct ReactionLayoutState {
    let recipe: CombatantHitReactionRecipe
    let impactScaleX: Double
    let impactScaleY: Double
    let impactDuration: Double
    let recoveryDuration: Double
    let impactOffsetX: Double
    let impactOffsetY: Double
    let recoverOffsetX: Double
    let recoverOffsetY: Double

    init(activeKind: CombatantHitReactionKind, recoilDirection: CombatantHitRecoilDirection) {
        let reactionRecipe = CombatFeedbackCardRecipes.cardReaction(for: activeKind)
        let defaultOffset = CGSize(
            width: CGFloat(reactionRecipe.offsetX[safe: 0]?.value ?? 0),
            height: CGFloat(reactionRecipe.offsetY[safe: 0]?.value ?? 0)
        )
        let isVerticalImpact = activeKind == .damage || activeKind == .critical
        let recipeScaleX: Double = reactionRecipe.scaleX[safe: 0]?.value ?? 1.0
        let recipeScaleY: Double = reactionRecipe.scaleY[safe: 0]?.value ?? 1.0
        let impactScales = isVerticalImpact
            ? recoilDirection.impactScales(scaleX: recipeScaleX, scaleY: recipeScaleY)
            : (x: recipeScaleX, y: recipeScaleY)
        let resolvedOffset: CGSize = isVerticalImpact
            ? recoilDirection.impactOffset(magnitude: abs(defaultOffset.width))
            : defaultOffset

        recipe = reactionRecipe
        impactScaleX = impactScales.x
        impactScaleY = impactScales.y
        impactDuration = reactionRecipe.scaleX[safe: 0]?.duration ?? 0.08
        recoveryDuration = reactionRecipe.scaleX[safe: 1]?.duration ?? 0.16
        impactOffsetX = Double(resolvedOffset.width)
        impactOffsetY = Double(resolvedOffset.height)
        recoverOffsetX = reactionRecipe.offsetX[safe: 1]?.value ?? 0
        recoverOffsetY = reactionRecipe.offsetY[safe: 1]?.value ?? 0
    }
}

private struct CardReactionAnimationState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
    var rotation = 0.0
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
