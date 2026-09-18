import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattlefieldView: View {
    let layout: BattleCardGridLayout.Metrics
    let presentation: BattlePresentationState
    let hapticsEnabled: Bool
    let onCombatantTap: (Combatant) -> Void
    let interactionState: BattleInteractionState

    var body: some View {
        VStack(spacing: layout.cardSpacing) {
            sizedPane(
                BattleCombatantProjectionPane(
                    presentation: presentation,
                    role: .enemy,
                    hapticsEnabled: hapticsEnabled,
                    onCombatantTap: onCombatantTap,
                ),
                size: layout.enemySize,
            )

            HStack(spacing: layout.cardSpacing) {
                sizedPane(
                    BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .hero,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: onCombatantTap,
                    ),
                    size: layout.partySize,
                )
                sizedPane(
                    BattleCombatantProjectionPane(
                        presentation: presentation,
                        role: .companion,
                        hapticsEnabled: hapticsEnabled,
                        onCombatantTap: onCombatantTap,
                    ),
                    size: layout.partySize,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(!interactionState.blocksCombatantTaps)
    }

    private func sizedPane(_ pane: some View, size: CGSize) -> some View {
        pane
            .frame(width: size.width, height: size.height)
    }
}

struct BattlefieldFeedbackOverlay: View {
    @Environment(\.displayScale) private var displayScale

    let layout: BattleCardGridLayout.Metrics
    let anchors: BattleCardGridLayout.FeedbackAnchors
    let enemyID: String?
    let heroID: String?
    let companionID: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            feedbackSlot(
                combatantID: enemyID,
                size: layout.enemySize,
                center: anchors.enemy,
            )
            feedbackSlot(
                combatantID: heroID,
                size: layout.partySize,
                center: anchors.hero,
            )
            feedbackSlot(
                combatantID: companionID,
                size: layout.partySize,
                center: anchors.companion,
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func feedbackSlot(
        combatantID: String?,
        size: CGSize,
        center: CGPoint,
    ) -> some View {
        if let combatantID {
            CombatFeedbackRasterSlot(
                combatantID: combatantID,
                displayScale: displayScale,
            )
            .frame(width: size.width, height: size.height)
            .position(center)
        }
    }
}
