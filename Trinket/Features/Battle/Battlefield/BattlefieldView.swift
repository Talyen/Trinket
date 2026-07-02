import SwiftUI

struct BattlefieldView: View {
    let layout: BattleCardGridLayout.Metrics
    let enemyPane: BattleCombatantPaneConfiguration
    let partyPanes: [BattleCombatantPaneConfiguration]
    let reduceMotion: Bool
    let onCombatantTap: (Combatant) -> Void

    var body: some View {
        VStack(spacing: layout.cardSpacing) {
            combatantPane(enemyPane, size: layout.enemySize)

            HStack(spacing: layout.cardSpacing) {
                ForEach(partyPanes) { pane in
                    combatantPane(pane, size: layout.partySize)
                }
            }
        }
        .padding(layout.outerPadding)
    }

    private func combatantPane(
        _ configuration: BattleCombatantPaneConfiguration,
        size: CGSize
    ) -> some View {
        BattleCombatantPane(
            configuration: configuration,
            reduceMotion: reduceMotion
        ) {
            onCombatantTap(configuration.combatant)
        }
        .frame(width: size.width, height: size.height)
    }
}
