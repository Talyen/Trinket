import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @ViewBuilder
    func rosterCombatantDetail(
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        hidesNavigationBar: Bool = false
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
                    get: { self.roster.current.loadout(for: combatant) },
                    set: { newValue in
                        var updated = self.roster.current
                        updated.setLoadout(newValue, for: combatant)
                        self.roster.current = updated
                    }
                ),
                equipmentLoadout: Binding(
                    get: { self.roster.current.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        var updated = self.roster.current
                        updated.setEquipmentLoadout(newValue, for: combatant)
                        self.roster.current = updated
                    }
                ),
                inventoryState: Binding(
                    get: { self.inventory.current },
                    set: { self.inventory.current = $0 }
                ),
                allowsEditing: roster.current.isUnlocked(combatant),
                hidesNavigationBar: hidesNavigationBar
            )
            .onAppear {
                self.sessionState.markCombatantAsViewed(id: combatantID)
            }
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Pet Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }
}
