import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct ItemSlotPickerView: View {
    let slot: ItemSlot
    @Binding var equipmentLoadout: EquipmentLoadout
    @Binding var inventoryState: PlayerInventoryState
    @Environment(\.dismiss) private var dismiss
    @State private var itemOrder: [String] = []
    @State private var selectedItemID: String?

    var body: some View {
        List {
            Section {
                ForEach(orderedItems) { item in
                    Button {
                        selectedItemID = item.id
                        equipmentLoadout.equip(item, in: slot)
                        dismiss()
                    } label: {
                        let isSelected = item.id == (selectedItemID ?? equipmentLoadout.itemID(for: slot))
                        HStack(spacing: 14) {
                            ItemCard(item: item, showsAffixCount: false, showsName: false)
                                .frame(height: 133)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.displayName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(item.affixes.prefix(4)) { affix in
                                        KeywordDescriptionText(text: affix.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(TrinketDesign.Colors.selection)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("Equip \(item.displayName)")
                    .accessibilityValue(equipmentLoadout.itemID(for: slot) == item.id ? "Equipped" : "Available")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sensoryFeedback(.selection, trigger: selectedItemID)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Equip \(slot.displayName)")
        .navigationBarTitleDisplayMode(.inline)
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
