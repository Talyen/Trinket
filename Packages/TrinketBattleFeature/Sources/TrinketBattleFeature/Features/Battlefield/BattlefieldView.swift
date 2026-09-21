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
