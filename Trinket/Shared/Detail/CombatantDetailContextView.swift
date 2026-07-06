import BattleEngine
import SwiftUI
import TrinketContent
import TrinketPersistence

struct CombatantDetailContextView: View {
    @Environment(AppState.self) private var appState
    let context: CombatantDetailContext
    var hidesNavigationBar = true

    var body: some View {
        switch context {
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
                combatant: combatant,
                progression: rosterState.progression(for: combatant),
                loadout: rosterBinding(for: combatant),
                equipmentLoadout: equipmentBinding(for: combatant),
                inventoryState: inventoryBinding,
                allowsEditing: rosterState.isUnlocked(combatant),
                hidesNavigationBar: hidesNavigationBar
            )
        } else {
            ContentUnavailableView(missingTitle(for: kind), systemImage: "questionmark.circle")
                .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private var inventoryBinding: Binding<PlayerInventoryState> {
        Binding(
            get: { appState.inventory.current },
            set: { appState.inventory.current = $0 }
        )
    }

    private func rosterBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding(
            get: { appState.roster.current.loadout(for: combatant) },
            set: { newValue in
                var updated = appState.roster.current
                updated.setLoadout(newValue, for: combatant)
                appState.roster.current = updated
            }
        )
    }

    private func equipmentBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding(
            get: { appState.roster.current.equipmentLoadout(for: combatant) },
            set: { newValue in
                var updated = appState.roster.current
                updated.setEquipmentLoadout(newValue, for: combatant)
                appState.roster.current = updated
            }
        )
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
