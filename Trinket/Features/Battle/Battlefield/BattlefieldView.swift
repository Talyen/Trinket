import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattlefieldView<EnemyPane: View, HeroPane: View, CompanionPane: View>: View {
    let layout: BattleCardGridLayout.Metrics
    let enemyPane: EnemyPane
    let heroPane: HeroPane
    let companionPane: CompanionPane

    var body: some View {
        VStack(spacing: layout.cardSpacing) {
            sizedPane(enemyPane, size: layout.enemySize)

            HStack(spacing: layout.cardSpacing) {
                sizedPane(heroPane, size: layout.partySize)
                sizedPane(companionPane, size: layout.partySize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func sizedPane(_ pane: some View, size: CGSize) -> some View {
        pane
            .frame(width: size.width, height: size.height)
            .clipShape(TrinketDesign.cardShape)
    }
}
