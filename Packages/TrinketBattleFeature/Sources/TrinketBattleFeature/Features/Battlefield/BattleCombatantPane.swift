import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatantCardChrome: ViewModifier {
    var borderOpacity: Double = 1

    func body(content: Content) -> some View {
        content
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(
                    TrinketDesign.Colors.subtleStroke,
                    lineWidth: 1,
                )
                .opacity(borderOpacity)
            }
    }
}

extension View {
    func combatantCardChrome(borderOpacity: Double = 1) -> some View {
        modifier(CombatantCardChrome(borderOpacity: borderOpacity))
    }
}

struct BattleCombatantPane: View {
    @Environment(\.displayScale) private var displayScale
    let combatant: Combatant
    let presentation: BattlePresentationState
    let health: Int
    let maxHealth: Int
    let mana: Int
    let maxMana: Int
    let borderAccentKeyword: Keyword?
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
                ) {
                    CombatantStatusEffectPresentation(keyword: isDefeated ? nil : borderAccentKeyword) {
                        framedCard
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(TrinketDesign.cardShape)
                .animation(BattleMotion.scrim, value: isDefeated)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .trinketPresentationVisibility(!isDefeated, opacity: 1)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.battleCard(name: combatant.name))
    }

    @ViewBuilder
    private var framedCard: some View {
        let card = ZStack(alignment: .bottom) {
            artworkPresentation
            resourceBars
        }
        .overlay(alignment: .bottom) {
            if !isDefeated, recoilDirection == .up {
                BossLyrics(bossID: combatant.id, presentation: presentation)
                    .padding(.horizontal, 8)
                    .padding(.bottom, TrinketDesign.Bars.battleHeight * (hasMana ? 2 : 1) + 6)
            }
        }
        if isDefeated, recoilDirection == .up {
            card
        } else {
            card
                .combatantCardChrome()
                .overlay {
                    cardBorder
                        .opacity(isDefeated ? 0 : 1)
                }
        }
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

    @ViewBuilder
    private var artworkPresentation: some View {
        if isDefeated, recoilDirection == .up {
            BattleSliceArtwork {
                artworkLayer
                    .combatantCardChrome()
                    .overlay { feedbackLayer }
            }
        } else {
            artworkLayer
                .saturation(isDefeated ? 0 : 1)
                .colorMultiply(isDefeated ? .gray : .white)
                .overlay { feedbackLayer }
        }
    }

    private var feedbackLayer: some View {
        CombatFeedbackRasterSlot(
            combatantID: combatant.id,
            displayScale: displayScale,
            bottomInset: TrinketDesign.Bars.battleHeight * (hasMana ? 2 : 1),
        )
        .allowsHitTesting(false)
    }

    private var isDefeated: Bool {
        health <= 0
    }

    private var artworkLayer: some View {
        CombatantArtwork(combatant: combatant, variant: .battle)
    }

    private var resourceBars: some View {
        VStack(spacing: 0) {
            CombatResourceBar(
                value: health,
                maxValue: maxHealth,
                style: .healthBattle,
            )
            .overlay { BattleResourceCueOverlay(combatantID: combatant.id, keyword: .health) }

            if hasMana {
                CombatResourceBar(value: mana, maxValue: maxMana, style: .mana)
                    .overlay { BattleResourceCueOverlay(combatantID: combatant.id, keyword: .mana) }
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(isDefeated ? 0 : 1)
        .animation(BattleMotion.scrim, value: isDefeated)
    }
}

private struct CombatantHitReactionLane<Artwork: View>: View {
    @Environment(BattleSession.self) private var battleSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let combatantID: String
    let hapticsEnabled: Bool
    let recoilDirection: CombatantHitRecoilDirection
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

    @ViewBuilder
    private func hitReactionAnimator() -> some View {
        if reduceMotion {
            artwork()
        } else {
            animatedHitReaction()
        }
    }

    private func animatedHitReaction() -> some View {
        let card = artwork()
        let layout = ReactionLayoutState(
            activeKind: activeKind,
            recoilDirection: recoilDirection,
        )
        return KeyframeAnimator(
            initialValue: CardReactionAnimationState(),
            trigger: playToken,
        ) { state in
            card
                .scaleEffect(x: state.scaleX, y: state.scaleY, anchor: layout.anchor)
                .rotationEffect(.degrees(state.rotation), anchor: layout.anchor)
                .rotation3DEffect(
                    .degrees(state.rotationX), axis: (x: 1, y: 0, z: 0),
                    anchor: layout.anchor, perspective: 0.35,
                )
                .offset(x: state.offsetX, y: state.offsetY)
        } keyframes: { _ in
            KeyframeTrack(\.scaleX) {
                scaleKeyframes(impact: layout.impactScaleX, recovery: layout.recoveryScaleX, layout: layout)
            }
            KeyframeTrack(\.scaleY) {
                scaleKeyframes(impact: layout.impactScaleY, recovery: layout.recoveryScaleY, layout: layout)
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
                    CubicKeyframe(layout.impactRotation, duration: layout.impactDuration)
                    CubicKeyframe(0, duration: layout.recoveryDuration)
                } else {
                    for sample in samples {
                        CubicKeyframe(sample.value, duration: sample.duration)
                    }
                }
            }
            KeyframeTrack(\.rotationX) {
                CubicKeyframe(layout.impactRotationX, duration: layout.impactDuration)
                CubicKeyframe(0, duration: layout.recoveryDuration)
            }
        }
    }

    @KeyframeTrackContentBuilder<Double>
    private func scaleKeyframes(
        impact: Double, recovery: Double, layout: ReactionLayoutState,
    ) -> some KeyframeTrackContent<Double> {
        if activeKind == .dodge {
            CubicKeyframe(impact, duration: layout.impactDuration)
            CubicKeyframe(recovery, duration: layout.recoveryDuration)
        } else {
            SpringKeyframe(impact, duration: layout.impactDuration, spring: .snappy(duration: layout.impactDuration))
            SpringKeyframe(recovery, duration: layout.recoveryDuration, spring: .bouncy(duration: layout.recoveryDuration))
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
    let impactRotation: Double
    let impactRotationX: Double
    let anchor: UnitPoint

    init(activeKind: CombatantHitReactionKind, recoilDirection: CombatantHitRecoilDirection) {
        let reactionRecipe = CombatFeedbackCardRecipes.cardReaction(for: activeKind)
        let defaultOffset = CGSize(
            width: CGFloat(reactionRecipe.impact.pose.offsetX),
            height: CGFloat(reactionRecipe.impact.pose.offsetY),
        )
        let isVerticalImpact = activeKind == .damage || activeKind == .critical || activeKind == .block
        let recipeScaleX: Double = reactionRecipe.impact.pose.scaleX
        let recipeScaleY: Double = reactionRecipe.impact.pose.scaleY
        let impactScales = isVerticalImpact
            ? recoilDirection.impactScales(scaleX: recipeScaleX, scaleY: recipeScaleY)
            : (x: recipeScaleX, y: recipeScaleY)
        let dodgeDirection = activeKind == .dodge && recoilDirection == .up ? -1.0 : 1.0
        let resolvedOffset: CGSize = isVerticalImpact
            ? recoilDirection.impactOffset(magnitude: abs(defaultOffset.width))
            : CGSize(width: defaultOffset.width * dodgeDirection, height: defaultOffset.height * dodgeDirection)

        recipe = reactionRecipe
        impactScaleX = impactScales.x
        impactScaleY = impactScales.y
        recoveryScaleX = reactionRecipe.recovery.pose.scaleX
        recoveryScaleY = reactionRecipe.recovery.pose.scaleY
        impactDuration = reactionRecipe.impact.duration
        recoveryDuration = reactionRecipe.recovery.duration
        impactOffsetX = Double(resolvedOffset.width)
        impactOffsetY = Double(resolvedOffset.height)
        recoverOffsetX = reactionRecipe.recovery.pose.offsetX
        recoverOffsetY = reactionRecipe.recovery.pose.offsetY
        impactRotation = reactionRecipe.impact.pose.rotation * dodgeDirection
        impactRotationX = reactionRecipe.impact.pose.rotationX * dodgeDirection
        anchor = activeKind == .dodge ? UnitPoint(x: 0.5, y: recoilDirection == .down ? 0.9 : 0.1) : .center
    }
}

private struct CardReactionAnimationState {
    var scaleX = 1.0
    var scaleY = 1.0
    var offsetX = 0.0
    var offsetY = 0.0
    var rotation = 0.0
    var rotationX = 0.0
}

private struct CombatantStatusBorderPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let keyword: Keyword

    @State private var pulseAmount = 0.0

    var body: some View {
        Group {
            if reduceMotion {
                CombatantStatusBorderPulseStroke(keyword: keyword, pulseAmount: 1)
            } else {
                CombatantStatusBorderPulseStroke(keyword: keyword, pulseAmount: pulseAmount)
                    .onAppear {
                        pulseAmount = 0
                        withAnimation(
                            BattleMotion.statusBorderPulse.repeatForever(autoreverses: true),
                        ) {
                            pulseAmount = 1
                        }
                    }
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
