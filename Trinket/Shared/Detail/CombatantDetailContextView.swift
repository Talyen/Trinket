import SwiftUI
import TrinketContent
import TrinketPersistence

struct CombatantDetailContextView: View {
    @Environment(AppState.self) private var appState
    let context: CombatantDetailContext
    var hidesNavigationBar = true

    var body: some View {
        switch context.presentation {
        case let .roster(kind, combatantID):
            rosterDetail(kind: kind, combatantID: combatantID)
        case let .snapshot(detail):
            CombatantDetailPane(snapshot: detail, hidesNavigationBar: hidesNavigationBar)
        }
    }

    @ViewBuilder
    private func rosterDetail(
        kind: CombatantDetailContext.Kind,
        combatantID: String
    ) -> some View {
        let rosterState = appState.roster.current
        let combatants = rosterState.configuredCombatants(sourceCombatants(for: kind))

        if let combatant = combatants.first(where: { $0.id == combatantID }) {
            CombatantDetailPane(
                appState: appState,
                combatant: combatant,
                rosterState: rosterState,
                hidesNavigationBar: hidesNavigationBar
            )
        } else {
            ContentUnavailableView(missingTitle(for: kind), systemImage: "questionmark.circle")
                .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func sourceCombatants(for kind: CombatantDetailContext.Kind) -> [Combatant] {
        switch kind {
        case .hero:
            GameContent.heroes
        case .pet:
            GameContent.pets
        }
    }

    private func missingTitle(for kind: CombatantDetailContext.Kind) -> String {
        switch kind {
        case .hero:
            "Hero Not Found"
        case .pet:
            "Pet Not Found"
        }
    }
}
