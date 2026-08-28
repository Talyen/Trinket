import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattlefieldView<EnemyPane: View, HeroPane: View, CompanionPane: View>: View {
    let layout: BattleCardGridLayout.Metrics
    let enemyPane: EnemyPane
    let heroPane: HeroPane
    let companionPane: CompanionPane
    let interactionState: BattleInteractionState

    var body: some View {
        VStack(spacing: layout.cardSpacing) {
            sizedPane(enemyPane, size: layout.enemySize)

            HStack(spacing: layout.cardSpacing) {
                sizedPane(heroPane, size: layout.partySize)
                sizedPane(companionPane, size: layout.partySize)
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
                center: anchors.enemy
            )
            feedbackSlot(
                combatantID: heroID,
                size: layout.partySize,
                center: anchors.hero
            )
            feedbackSlot(
                combatantID: companionID,
                size: layout.partySize,
                center: anchors.companion
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func feedbackSlot(
        combatantID: String?,
        size: CGSize,
        center: CGPoint
    ) -> some View {
        if let combatantID {
            CombatFeedbackRasterSlot(
                combatantID: combatantID,
                cardHeight: size.height,
                displayScale: displayScale
            )
            .frame(width: size.width, height: size.height)
            .position(center)
        }
    }
}
