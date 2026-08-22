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
                aim: CombatantAttackAim.aim(isPartyMember: recoilDirection == .down)
            ) {
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
    /// storage is ObservationIgnored and only this combatant's bridge fires.
    @State private var playToken = 0
    @State private var activeKind: CombatantHitReactionKind = .none
    @State private var latestReactionID = 0
    @State private var reactionBridgeOwnerID = UUID()

    var body: some View {
        hitReactionAnimator()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .trinketSensoryFeedback(
                reactionFeedback(for: activeKind == .none ? nil : activeKind),
                trigger: playToken,
                enabled: hapticsEnabled
            )
            .onAppear {
                installHitReactionBridge()
                adoptLatestReactionIfNeeded()
            }
            .onDisappear {
                battleSession.feedback.uninstallHitReactionBridge(ownerID: reactionBridgeOwnerID)
            }
            .onChange(of: combatantID) { _, _ in
                installHitReactionBridge()
                adoptLatestReactionIfNeeded()
            }
    }

    private func hitReactionAnimator() -> some View {
        let layout = ReactionLayoutState(
            activeKind: activeKind,
            recoilDirection: recoilDirection
        )
        return KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: playToken
        ) { state in
            hitReactionArtwork(state)
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
                let samples = layout.recipe.rotation
                if samples.isEmpty {
                    CubicKeyframe(0, duration: layout.impactDuration + layout.recoveryDuration)
                } else {
                    for sample in samples {
                        CubicKeyframe(sample.value, duration: sample.duration)
                    }
                }
            }
        }
    }

    private func hitReactionArtwork(_ state: CardReactionAnimationState) -> some View {
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
    }

    @ViewBuilder
    private var cardBorder: some View {
        if borderAccentKeyword == .deathsDoor, let keyword = borderAccentKeyword {
            CombatantStatusBorderPulse(keyword: keyword)
        } else if let buffAuraKind {
            CombatantBuffAuraLane(kind: buffAuraKind)
        } else {
            TrinketDesign.cardShape.strokeBorder(
                TrinketDesign.Colors.subtleStroke,
                lineWidth: 1
            )
        }
    }

    private func installHitReactionBridge() {
        battleSession.feedback.installHitReactionBridge(
            ownerID: reactionBridgeOwnerID,
            combatantID: combatantID
        ) {
            adoptLatestReactionIfNeeded()
        }
    }

    private func adoptLatestReactionIfNeeded() {
        guard let reaction = battleSession.feedback.hitReactionsByTargetID[combatantID],
              reaction.id != latestReactionID
        else { return }
        activeKind = reaction.kind
        latestReactionID = reaction.id
        playToken &+= 1
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

/// Death's Door pulse owns its animation so KeyframeAnimator is not rebuilt every tick.
private struct CombatantStatusBorderPulse: View {
    let keyword: Keyword

    @State private var pulseAmount = 0.0

    var body: some View {
        CombatantStatusBorderPulseStroke(
            keyword: keyword,
            pulseAmount: pulseAmount
        )
        .onAppear {
            pulseAmount = 0
            withAnimation(
                TrinketMotion.Battle.statusBorderPulse.repeatForever(autoreverses: true)
            ) {
                pulseAmount = 1
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CombatantStatusBorderPulseStroke: View, Animatable {
    let keyword: Keyword
    var pulseAmount: Double

    nonisolated var animatableData: Double {
        get { pulseAmount }
        set { pulseAmount = newValue }
    }

    var body: some View {
        let dim = TrinketMotion.Battle.statusBorderPulseDimOpacity
        let opacity = dim + (1 - dim) * pulseAmount
        TrinketDesign.cardShape.strokeBorder(
            keyword.visualStyle.color.opacity(opacity),
            lineWidth: 1
        )
    }
}

struct CombatManaBar: View {
    let mana: Int
    let maxMana: Int
    @State private var displayedMana: Int
    @State private var restoreGlowOpacity: Double = 0

    init(mana: Int, maxMana: Int) {
        self.mana = mana
        self.maxMana = maxMana
        _displayedMana = State(initialValue: mana)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(TrinketDesign.Colors.battleHealthTrack)

            Rectangle()
                .fill(Keyword.mana.visualStyle.color)
                .scaleEffect(x: displayedFraction, y: 1, anchor: .leading)

            Rectangle()
                .fill(Keyword.mana.visualStyle.color)
                .scaleEffect(x: displayedFraction, y: 1, anchor: .leading)
                .opacity(restoreGlowOpacity)
                .blendMode(.plusLighter)
        }
        .frame(maxWidth: .infinity)
        .frame(height: TrinketDesign.Metrics.battleHealthBarHeight)
        .clipShape(Rectangle())
        .onChange(of: mana) { oldMana, newMana in
            if newMana > oldMana {
                restoreGlowOpacity = 0.36
                withAnimation(.easeOut(duration: TrinketMotion.Interaction.manaRestoreDuration)) {
                    displayedMana = newMana
                    restoreGlowOpacity = 0
                }
            } else {
                withAnimation(.easeOut(duration: TrinketMotion.Interaction.manaSpendDuration)) {
                    displayedMana = newMana
                }
            }
        }
    }

    private var displayedFraction: Double {
        guard maxMana > 0 else { return 0 }
        return min(max(Double(displayedMana) / Double(maxMana), 0), 1)
    }
}
