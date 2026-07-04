import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

struct CombatantCollectionDetailView: View {
    @Environment(AppState.self) private var appState
    let combatant: Combatant
    let progression: CombatantProgression
    let inventoryState: PlayerInventoryState
    @Binding var loadout: AbilityLoadout
    @Binding var equipmentLoadout: EquipmentLoadout
    var allowsEditing = true
    var battleHealth: Int?
    var activeEffectSummaries: [EffectSummary] = []
    var navigationChrome: CombatantDetailNavigationChrome = .visible
    @State private var selectedItemSlot: ItemSlot?

    var body: some View {
        CombatantDetailPane(
            combatant: combatant,
            progression: progression,
            loadout: $loadout,
            equipmentLoadout: $equipmentLoadout,
            inventoryState: inventoryBinding,
            allowsEditing: allowsEditing,
            battleHealth: battleHealth,
            activeEffectSummaries: activeEffectSummaries,
            navigationChrome: navigationChrome,
            selectedItemSlot: $selectedItemSlot
        )
        .sheet(item: $selectedItemSlot) { slot in
            NavigationStack {
                ItemSlotPickerView(
                    slot: slot,
                    equipmentLoadout: $equipmentLoadout,
                    inventoryState: inventoryBinding
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var inventoryBinding: Binding<PlayerInventoryState> {
        Binding(
            get: { appState.inventory.current },
            set: { appState.inventory.current = $0 }
        )
    }
}
