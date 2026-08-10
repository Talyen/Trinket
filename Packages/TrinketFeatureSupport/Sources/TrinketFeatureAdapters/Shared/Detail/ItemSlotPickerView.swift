import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct ItemSlotPickerView: View {
    let slot: ItemSlot
    let equipmentLoadout: EquipmentLoadout
    let inventoryItems: [InventoryItem]
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
                        .overlay(alignment: .topTrailing) {
                            if equippedInSiblingSlotIDs.contains(item.id) {
                                Text("Equipped")
                                    .trinketTypography(.caption)
                                    .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
                                    .padding(.horizontal, TrinketDesign.Metrics.tightSpacing)
                                    .padding(.vertical, 2)
                                    .background(TrinketDesign.Colors.accent, in: Capsule())
                                    .padding(TrinketDesign.Metrics.tightSpacing)
                            }
                        }
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
        let items = inventoryItems.filter { slot.accepts($0.baseType.slot) }
        guard !itemOrder.isEmpty else { return entrySortedItems }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ordered = itemOrder.compactMap { itemsByID[$0] }
        let orderedIDs = Set(itemOrder)
        let newItems = items.filter { !orderedIDs.contains($0.id) }
        return ordered + newItems
    }

    private var entrySortedItems: [InventoryItem] {
        let items = inventoryItems.filter { slot.accepts($0.baseType.slot) }
        guard
            let equippedID = equipmentLoadout.itemID(for: slot),
            let equippedItem = items.first(where: { $0.id == equippedID })
        else {
            return items
        }

        return [equippedItem] + items.filter { $0.id != equippedID }
    }

    /// Item IDs worn in sibling slots of the same family, so the picker can mark
    /// them as equipped elsewhere (selecting one moves it between slots).
    private var equippedInSiblingSlotIDs: Set<String> {
        equipmentLoadout.itemIDs(inFamilyOf: slot)
            .subtracting([equipmentLoadout.itemID(for: slot)].compactMap(\.self))
    }
}
