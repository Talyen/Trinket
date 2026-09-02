import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleCombatantPane: View {
    @Environment(BattleSession.self) private var battleSession
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
                aim: CombatantAttackAim.aim(isPartyMember: recoilDirection == .down),
            ) {
                CombatantHitReactionLane(
                    combatantID: combatant.id,
                    hapticsEnabled: hapticsEnabled,
                    recoilDirection: recoilDirection,
                    borderVisible: !isDefeated,
                    borderAccentKeyword: borderAccentKeyword,
                    buffAuraKind: buffAuraKind,
                ) {
                    ZStack(alignment: .bottom) {
                        artworkPresentation
                        resourceBars
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(TrinketDesign.cardShape)
                .animation(BattleMotion.scrim, value: isDefeated)
            }
        }
        .trinketQuietTapButtonStyle()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.battleCard(name: combatant.name))
    }

    @ViewBuilder
    private var artworkPresentation: some View {
        if isDefeated {
            if recoilDirection == .up {
                BattleSliceArtwork {
                    artworkLayer
                }
            } else {
                CardDissolveArtwork {
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
        ZStack {
            CombatantArtwork(combatant: combatant, variant: .battle)
            if let highlight = battleSession.spectacle
                .ultimateHighlightsByActorID[combatant.id] {
                UltimateInFrameView(highlight: highlight, effectsVolume: battleSession.effectsVolume)
                    .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: BattleMotion.ultimateInFrameFadeDuration),
            value: battleSession.spectacle.ultimateHighlightsByActorID[combatant.id]?.id,
        )
    }

    private var resourceBars: some View {
        VStack(spacing: 0) {
            CombatResourceBar(
                value: health,
                maxValue: maxHealth,
                style: .healthBattle,
            )

            if hasMana {
                CombatResourceBar(value: mana, maxValue: maxMana, style: .mana)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isDefeated ? 0 : 1)
        .animation(BattleMotion.scrim, value: isDefeated)
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
                enabled: hapticsEnabled,
            )
            .onAppear {
                installHitReactionBridge()
            }
            .onDisappear {
                battleSession.feedback.uninstallHitReactionBridge(ownerID: reactionBridgeOwnerID)
            }
            .onChange(of: combatantID) { _, _ in
                adoptReaction(nil)
                installHitReactionBridge()
            }
    }

    private func hitReactionAnimator() -> some View {
        let layout = ReactionLayoutState(
            activeKind: activeKind,
            recoilDirection: recoilDirection,
        )
        return KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: playToken,
        ) { state in
            hitReactionArtwork(state)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                SpringKeyframe(
                    layout.impactScaleX,
                    duration: layout.impactDuration,
                    spring: .snappy(duration: layout.impactDuration),
                )
                SpringKeyframe(
                    layout.recoveryScaleX,
                    duration: layout.recoveryDuration,
                    spring: .bouncy(duration: layout.recoveryDuration),
                )
            }
            KeyframeTrack(\.scaleY) {
                SpringKeyframe(
                    layout.impactScaleY,
                    duration: layout.impactDuration,
                    spring: .snappy(duration: layout.impactDuration),
                )
                SpringKeyframe(
                    layout.recoveryScaleY,
                    duration: layout.recoveryDuration,
                    spring: .bouncy(duration: layout.recoveryDuration),
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
            .clipShape(TrinketDesign.cardShape)
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
        } else {
            TrinketDesign.cardShape.strokeBorder(
                TrinketDesign.Colors.subtleStroke,
                lineWidth: 1,
            )
        }
    }

    private func installHitReactionBridge() {
        battleSession.feedback.installHitReactionBridge(
            ownerID: reactionBridgeOwnerID,
            combatantID: combatantID,
        ) { reaction in
            adoptReaction(reaction)
        }
    }

    private func adoptReaction(_ reaction: CombatantHitReaction?) {
        guard let reaction else {
            activeKind = .none
            latestReactionID = 0
            return
        }
        guard reaction.id != latestReactionID else { return }
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

private struct ReactionLayoutState {
    let recipe: CombatantHitReactionRecipe
    let impactScaleX: Double
    let impactScaleY: Double
    let recoveryScaleX: Double
    let recoveryScaleY: Double
    let impactDuration: Double
    let recoveryDuration: Double
    let impactOffsetX: Double
    let impactOffsetY: Double
    let recoverOffsetX: Double
    let recoverOffsetY: Double

    init(activeKind: CombatantHitReactionKind, recoilDirection: CombatantHitRecoilDirection) {
        let reactionRecipe = CombatFeedbackCardRecipes.cardReaction(for: activeKind)
        let defaultOffset = CGSize(
            width: CGFloat(reactionRecipe.rawImpactOffsetX),
            height: CGFloat(reactionRecipe.rawImpactOffsetY),
        )
        let isVerticalImpact = activeKind == .damage || activeKind == .critical
        let recipeScaleX: Double = reactionRecipe.rawImpactScaleX
        let recipeScaleY: Double = reactionRecipe.rawImpactScaleY
        let impactScales = isVerticalImpact
            ? recoilDirection.impactScales(scaleX: recipeScaleX, scaleY: recipeScaleY)
            : (x: recipeScaleX, y: recipeScaleY)
        let resolvedOffset: CGSize = isVerticalImpact
            ? recoilDirection.impactOffset(magnitude: abs(defaultOffset.width))
            : defaultOffset

        recipe = reactionRecipe
        impactScaleX = impactScales.x
        impactScaleY = impactScales.y
        recoveryScaleX = reactionRecipe.recoveryScaleX
        recoveryScaleY = reactionRecipe.recoveryScaleY
        impactDuration = reactionRecipe.impactDuration
        recoveryDuration = reactionRecipe.recoveryDuration
        impactOffsetX = Double(resolvedOffset.width)
        impactOffsetY = Double(resolvedOffset.height)
        recoverOffsetX = reactionRecipe.recoverOffsetX
        recoverOffsetY = reactionRecipe.recoverOffsetY
    }
}

private struct CardReactionAnimationState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
    var rotation = 0.0
}

private struct CombatantStatusBorderPulse: View {
    let keyword: Keyword

    @State private var pulseAmount = 0.0

    var body: some View {
        CombatantStatusBorderPulseStroke(
            keyword: keyword,
            pulseAmount: pulseAmount,
        )
        .onAppear {
            pulseAmount = 0
            withAnimation(
                BattleMotion.statusBorderPulse.repeatForever(autoreverses: true),
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
        let dim = BattleMotion.statusBorderPulseDimOpacity
        let opacity = dim + (1 - dim) * pulseAmount
        TrinketDesign.cardShape.strokeBorder(
            keyword.visualStyle.color.opacity(opacity),
            lineWidth: 1,
        )
    }
}
