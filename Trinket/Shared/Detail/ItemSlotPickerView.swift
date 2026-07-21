import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct ItemSlotPickerView: View {
    let slot: ItemSlot
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onEquip: (InventoryItem) -> Void

    @State private var itemOrder: [String] = []
    @State private var selectedItem: InventoryItem?

    var body: some View {
        Group {
            if orderedItems.isEmpty {
                ContentUnavailableView("No Items to Equip", systemImage: "shippingbox")
            } else {
                OptionPickerGrid(
                    items: orderedItems,
                    isSelected: { item in
                        item.id == equipmentLoadout.itemID(for: slot)
                    },
                    onSelect: { selectedItem = $0 },
                    accessibilityIdentifier: { item in
                        AccessibilityID.LoadoutPicker.itemCandidate(item.id)
                    },
                    card: { item, isSelected in
                        ItemCard(
                            item: item,
                            showsAffixCount: false,
                            isSelected: isSelected
                        )
                    }
                )
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemGrid(slot.displayName))
            }
        }
        .navigationTitle("Equip \(slot.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            ItemDetailView(
                item: item,
                primaryActionTitle: "Equip \(slot.displayName)",
                primaryActionAccessibilityID: AccessibilityID.LoadoutPicker.equipItem(item.id),
                dismissAfterPrimaryAction: true,
                onPrimaryAction: {
                    onEquip(item)
                    selectedItem = nil
                }
            )
        }
        .onAppear {
            if itemOrder.isEmpty {
                itemOrder = entrySortedItems.map(\.id)
            }
        }
    }

    private var orderedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard !itemOrder.isEmpty else { return entrySortedItems }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ordered = itemOrder.compactMap { itemsByID[$0] }
        let orderedIDs = Set(itemOrder)
        let newItems = items.filter { !orderedIDs.contains($0.id) }
        return ordered + newItems
    }

    private var entrySortedItems: [InventoryItem] {
        let items = inventoryState.items(for: slot)
        guard
            let equippedID = equipmentLoadout.itemID(for: slot),
            let equippedItem = items.first(where: { $0.id == equippedID })
        else {
            return items
        }

        return [equippedItem] + items.filter { $0.id != equippedID }
    }
}
