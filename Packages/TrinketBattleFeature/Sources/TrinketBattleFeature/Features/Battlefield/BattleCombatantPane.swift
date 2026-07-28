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
    let hapticsEnabled: Bool
    let cinematicNamespace: Namespace.ID
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
                        borderAccentKeyword: borderAccentKeyword
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

                        // Invisible source for Ultimate matched-geometry expand from this card.
                        Color.clear
                            .frame(width: 1, height: 1)
                            .matchedGeometryEffect(
                                id: "ultimate-source-\(combatant.id)",
                                in: cinematicNamespace,
                                isSource: true
                            )
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
            BattleDissolveArtwork(celebratesDefeat: recoilDirection != .down) {
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
        let recipe = CombatFeedbackCardRecipes.cardReaction(for: activeKind)
        let defaultOffset = CGSize(
            width: CGFloat(recipe.offsetX[safe: 0]?.value ?? 0),
            height: CGFloat(recipe.offsetY[safe: 0]?.value ?? 0)
        )
        let impactOffset = impactOffset(
            for: activeKind,
            magnitude: abs(defaultOffset.width),
            defaultOffset: defaultOffset
        )
        let isVerticalImpact = activeKind == .damage || activeKind == .critical
        let recipeScaleX = recipe.scaleX[safe: 0]?.value ?? 1.0
        let recipeScaleY = recipe.scaleY[safe: 0]?.value ?? 1.0
        let impactScales = isVerticalImpact
            ? recoilDirection.impactScales(scaleX: recipeScaleX, scaleY: recipeScaleY)
            : (x: recipeScaleX, y: recipeScaleY)
        let impactScaleX = impactScales.x
        let impactScaleY = impactScales.y
        let impactDuration = recipe.scaleX[safe: 0]?.duration ?? 0.08
        let recoveryDuration = recipe.scaleX[safe: 1]?.duration ?? 0.16
        // KeyframeAnimator interpolates Doubles; keep tracks typed explicitly.
        let impactOffsetX = Double(impactOffset.width)
        let impactOffsetY = Double(impactOffset.height)
        let recoverOffsetX = recipe.offsetX[safe: 1]?.value ?? 0
        let recoverOffsetY = recipe.offsetY[safe: 1]?.value ?? 0
        let borderColor = borderStrokeColor

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
                    TrinketDesign.cardShape.strokeBorder(
                        borderColor,
                        lineWidth: 1
                    )
                    .opacity(borderVisible ? 1 : 0)
                }
                .scaleEffect(x: state.scaleX, y: state.scaleY)
                .rotationEffect(.degrees(state.rotation))
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
                // Cubic guarantees the impact translation is reached; springs on
                // sub-0.1s segments can undershoot small offsets into invisibility.
                CubicKeyframe(impactOffsetX, duration: impactDuration)
                CubicKeyframe(recoverOffsetX, duration: recoveryDuration)
            }
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(impactOffsetY, duration: impactDuration)
                CubicKeyframe(recoverOffsetY, duration: recoveryDuration)
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(
                    recipe.rotation[safe: 0]?.value ?? 0,
                    duration: recipe.rotation[safe: 0]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 1]?.value ?? 0,
                    duration: recipe.rotation[safe: 1]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 2]?.value ?? 0,
                    duration: recipe.rotation[safe: 2]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 3]?.value ?? 0,
                    duration: recipe.rotation[safe: 3]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 4]?.value ?? 0,
                    duration: recipe.rotation[safe: 4]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 5]?.value ?? 0,
                    duration: recipe.rotation[safe: 5]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 6]?.value ?? 0,
                    duration: recipe.rotation[safe: 6]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 7]?.value ?? 0,
                    duration: recipe.rotation[safe: 7]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 8]?.value ?? 0,
                    duration: recipe.rotation[safe: 8]?.duration ?? 0.01
                )
                CubicKeyframe(
                    recipe.rotation[safe: 9]?.value ?? 0,
                    duration: recipe.rotation[safe: 9]?.duration ?? 0.01
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
            syncStatusBorderPulse(isActive: borderAccentKeyword != nil)
        }
        .onChange(of: borderAccentKeyword) { _, keyword in
            syncStatusBorderPulse(isActive: keyword != nil)
        }
    }

    private var borderStrokeColor: Color {
        guard let borderAccentKeyword else {
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

    private func impactOffset(
        for kind: CombatantHitReactionKind,
        magnitude: CGFloat,
        defaultOffset: CGSize
    ) -> CGSize {
        guard kind == .damage || kind == .critical else {
            return defaultOffset
        }
        return recoilDirection.impactOffset(magnitude: magnitude)
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
