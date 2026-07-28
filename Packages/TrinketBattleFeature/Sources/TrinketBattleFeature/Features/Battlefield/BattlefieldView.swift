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
        .allowsHitTesting(!interactionState.suppressCombatantTaps)
    }

    private func sizedPane(_ pane: some View, size: CGSize) -> some View {
        pane
            .frame(width: size.width, height: size.height)
    }
}

/// Fixed feedback anchors derived from the authored battlefield grid. This layer
/// is a sibling of combatant panes so attack and hit-reaction transforms do not
/// move floating combat text.
struct BattlefieldFeedbackOverlay: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    let layout: BattleCardGridLayout.Metrics
    let enemyID: String?
    let heroID: String?
    let companionID: String?

    var body: some View {
        GeometryReader { geometry in
            let anchors = BattleCardGridLayout.feedbackAnchors(
                containerWidth: geometry.size.width,
                layout: layout
            )
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
        }
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
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
            .frame(width: size.width, height: size.height)
            .position(center)
        }
    }
}
