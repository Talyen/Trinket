import SwiftUI
import TrinketContent
import TrinketPersistence

extension AppState {
    func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            roster.current.loadout(for: combatant)
        } set: { newValue in
            var updated = roster.current
            updated.setLoadout(newValue, for: combatant)
            roster.current = updated
        }
    }

    func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            roster.current.equipmentLoadout(for: combatant)
        } set: { newValue in
            var updated = roster.current
            updated.setEquipmentLoadout(newValue, for: combatant)
            roster.current = updated
        }
    }

    func inventoryBinding() -> Binding<PlayerInventoryState> {
        Binding(
            get: { inventory.current },
            set: { inventory.current = $0 }
        )
    }
}
