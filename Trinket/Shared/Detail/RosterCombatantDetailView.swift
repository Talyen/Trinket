import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Editable roster combatant detail wired from `AppState` save slices.
/// Lives in Shared so `State/` does not construct feature/shared views.
struct RosterCombatantDetailView: View {
    @Environment(AppState.self) private var appState

    let kind: CombatantDetailContext.Kind
    let combatantID: String
    var hidesNavigationBar = false

    var body: some View {
        let catalog: [Combatant] = switch kind {
        case .hero:
            GameContent.heroes
        case .companion:
            GameContent.companions
        }

        if let combatant = appState.roster
            .configuredCombatants(catalog)
            .first(where: { $0.id == combatantID }) {
            CombatantDetailPane(
                combatant: combatant,
                progression: appState.roster.progression(for: combatant),
                loadout: Binding(
                    get: { appState.roster.loadout(for: combatant) },
                    set: { newValue in
                        var updated = appState.roster
                        updated.setLoadout(newValue, for: combatant)
                        appState.roster = updated
                    }
                ),
                equipmentLoadout: Binding(
                    get: { appState.roster.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        var updated = appState.roster
                        updated.setEquipmentLoadout(newValue, for: combatant)
                        appState.roster = updated
                    }
                ),
                inventoryState: Binding(
                    get: { appState.inventory },
                    set: { appState.inventory = $0 }
                ),
                allowsEditing: appState.roster.isUnlocked(combatant),
                hidesNavigationBar: hidesNavigationBar
            )
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }
}
