import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @ViewBuilder
    func rosterCombatantDetail(
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        hidesNavigationBar: Bool = true
    ) -> some View {
        let catalog: [Combatant] = switch kind {
        case .hero:
            GameContent.heroes
        case .pet:
            GameContent.pets
        }

        if let combatant = roster.current
            .configuredCombatants(catalog)
            .first(where: { $0.id == combatantID }) {
            CombatantDetailPane(
                combatant: combatant,
                progression: roster.current.progression(for: combatant),
                loadout: Binding(
                    get: { roster.current.loadout(for: combatant) },
                    set: { newValue in
                        var updated = roster.current
                        updated.setLoadout(newValue, for: combatant)
                        roster.current = updated
                    }
                ),
                equipmentLoadout: Binding(
                    get: { roster.current.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        var updated = roster.current
                        updated.setEquipmentLoadout(newValue, for: combatant)
                        roster.current = updated
                    }
                ),
                inventoryState: Binding(
                    get: { inventory.current },
                    set: { inventory.current = $0 }
                ),
                allowsEditing: roster.current.isUnlocked(combatant),
                hidesNavigationBar: hidesNavigationBar
            )
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Pet Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }
}
