import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    var inventoryBinding: Binding<PlayerInventoryState> {
        Binding(
            get: { self.inventory.current },
            set: { self.inventory.current = $0 }
        )
    }

    func abilityLoadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding(
            get: { self.roster.current.loadout(for: combatant) },
            set: { newValue in
                var updated = self.roster.current
                updated.setLoadout(newValue, for: combatant)
                self.roster.current = updated
            }
        )
    }

    func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding(
            get: { self.roster.current.equipmentLoadout(for: combatant) },
            set: { newValue in
                var updated = self.roster.current
                updated.setEquipmentLoadout(newValue, for: combatant)
                self.roster.current = updated
            }
        )
    }

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
                loadout: abilityLoadoutBinding(for: combatant),
                equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                inventoryState: inventoryBinding,
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
