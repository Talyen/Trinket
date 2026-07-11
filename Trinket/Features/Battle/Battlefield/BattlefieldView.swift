import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattlefieldView: View {
    let layout: BattleCardGridLayout.Metrics
    let enemyPane: BattleCombatantPane
    let heroPane: BattleCombatantPane
    let petPane: BattleCombatantPane

    var body: some View {
        VStack(spacing: layout.cardSpacing) {
            sizedPane(enemyPane, size: layout.enemySize)

            HStack(spacing: layout.cardSpacing) {
                sizedPane(heroPane, size: layout.partySize)
                sizedPane(petPane, size: layout.partySize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func sizedPane(_ pane: BattleCombatantPane, size: CGSize) -> some View {
        pane
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}
