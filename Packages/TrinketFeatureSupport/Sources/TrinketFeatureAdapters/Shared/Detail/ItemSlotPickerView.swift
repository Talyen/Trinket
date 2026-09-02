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
        let eligible = eligibleItems
        let displayItems = ordered(items: eligible)

        Group {
            if displayItems.isEmpty {
                ContentUnavailableView("No Items to Equip", systemImage: "shippingbox")
            } else {
                OptionPickerGrid(
                    items: displayItems,
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
                            isSelected: isSelected,
                            shine: isSelected ? .keywords(item.plasmaKeywords) : nil,
                            shineLineWidth: isSelected ? 3 : 1.5,
                        )
                        .overlay(alignment: .topTrailing) {
                            if equippedInSiblingSlotIDs.contains(item.id) {
                                Text("Equipped")
                                    .trinketTypography(.caption)
                                    .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
                                    .padding(.horizontal, TrinketDesign.Spacing.tight)
                                    .padding(.vertical, 2)
                                    .background(TrinketDesign.Colors.accent, in: Capsule())
                                    .padding(TrinketDesign.Spacing.tight)
                            }
                        }
                    },
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
                onPrimaryAction: {
                    onEquip(item)
                    selectedItem = nil
                },
            )
        }
        .onAppear {
            if itemOrder.isEmpty {
                itemOrder = entrySorted(items: eligibleItems).map(\.id)
            }
        }
    }

    private var eligibleItems: [InventoryItem] {
        inventoryItems.filter {
            equipmentLoadout.canEquip($0, in: slot, inventory: inventoryItems)
        }
    }

    private func ordered(items: [InventoryItem]) -> [InventoryItem] {
        guard !itemOrder.isEmpty else { return entrySorted(items: items) }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let ordered = itemOrder.compactMap { itemsByID[$0] }
        let orderedIDs = Set(itemOrder)
        let newItems = items.filter { !orderedIDs.contains($0.id) }
        return ordered + newItems
    }

    private func entrySorted(items: [InventoryItem]) -> [InventoryItem] {
        guard
            let equippedID = equipmentLoadout.itemID(for: slot),
            let index = items.firstIndex(where: { $0.id == equippedID })
        else {
            return items
        }

        var result = items
        let equipped = result.remove(at: index)
        result.insert(equipped, at: 0)
        return result
    }

    private var equippedInSiblingSlotIDs: Set<String> {
        equipmentLoadout.itemIDs(inFamilyOf: slot)
            .subtracting([equipmentLoadout.itemID(for: slot)].compactMap(\.self))
    }
}
