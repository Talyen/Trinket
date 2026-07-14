import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct ItemSlotPickerView: View {
    let slot: ItemSlot
    let equipmentLoadout: EquipmentLoadout
    let inventoryState: PlayerInventoryState
    let onOpenDetail: (InventoryItem) -> Void

    @State private var itemOrder: [String] = []

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: TrinketDesign.Metrics.partyPickerGridItems,
                spacing: TrinketDesign.Metrics.largeSpacing
            ) {
                ForEach(orderedItems) { item in
                    optionButton(item)
                }
            }
            .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
            .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemGrid(slot.displayName))
        .navigationTitle("Equip \(slot.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if itemOrder.isEmpty {
                itemOrder = entrySortedItems.map(\.id)
            }
        }
    }

    private func optionButton(_ item: InventoryItem) -> some View {
        let isSelected = item.id == equipmentLoadout.itemID(for: slot)

        return Button {
            onOpenDetail(item)
        } label: {
            ZStack(alignment: .bottomLeading) {
                ItemCard(
                    item: item,
                    showsAffixCount: false,
                    showsName: false
                )

                TrinketHeroScrim.gradient(for: .detailHeader)
                    .clipShape(TrinketDesign.cardShape)

                Text(item.displayName)
                    .trinketTypography(.cardTitle)
                    .trinketOnArtText(.title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(TrinketDesign.Metrics.mediumSpacing)

                if isSelected {
                    ArtworkPickerSelectionBadge()
                }
            }
            .clipShape(TrinketDesign.cardShape)
            .trinketArtworkPickerSelectionBorder(isSelected: isSelected)
        }
        .buttonStyle(ArtworkNavigationCardButtonStyle())
        .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemCandidate(item.id))
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
