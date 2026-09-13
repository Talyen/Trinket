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
    let onUnequip: () -> Void

    @State private var model: ItemPickerItems
    @State private var filter = ItemPickerFilter()
    @State private var selectedItem: InventoryItem?

    init(
        slot: ItemSlot,
        equipmentLoadout: EquipmentLoadout,
        inventoryItems: [InventoryItem],
        initialItems: ItemPickerItems,
        onEquip: @escaping (InventoryItem) -> Void,
        onUnequip: @escaping () -> Void,
    ) {
        self.slot = slot
        self.equipmentLoadout = equipmentLoadout
        self.inventoryItems = inventoryItems
        self.onEquip = onEquip
        self.onUnequip = onUnequip
        _model = State(initialValue: initialItems)
    }

    var body: some View {
        let displayItems = model.matching(filter)
        let siblingIDs = equippedInSiblingSlotIDs

        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if filter.isActive {
                    Text("\(displayItems.count) of \(model.eligible.count) items")
                        .trinketTypography(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, TrinketDesign.Spacing.small)
                }
                if displayItems.isEmpty {
                    emptyState
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
                        artworkNameProvider: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
                        card: { item, isSelected in
                            ItemCard(
                                item: item,
                                showsAffixCount: false,
                                isSelected: isSelected,
                                shine: isSelected ? .keywords(item.plasmaKeywords) : nil,
                                shineLineWidth: isSelected ? 3 : 1.5,
                            )
                            .overlay(alignment: .topTrailing) {
                                if siblingIDs.contains(item.id) {
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
            .onChange(of: filter) { _, _ in
                if let first = displayItems.first {
                    proxy.scrollTo(first.id, anchor: .top)
                }
            }
        }
        .searchable(text: $filter.search, prompt: "Search equipment")
        .toolbar { filterToolbar }
        .navigationTitle("Equip \(slot.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            let isEquipped = equipmentLoadout.itemID(for: slot) == item.id
            ItemDetailView(
                item: item,
                primaryActionTitle: isEquipped ? "Unequip \(slot.displayName)" : "Equip \(slot.displayName)",
                primaryActionAccessibilityID: isEquipped
                    ? AccessibilityID.LoadoutPicker.unequipItem
                    : AccessibilityID.LoadoutPicker.equipItem(item.id),
                onPrimaryAction: {
                    if isEquipped {
                        onUnequip()
                    } else {
                        onEquip(item)
                    }
                },
            )
        }
        .onChange(of: inventoryItems, initial: true) { _, _ in
            model.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
        }
        .onChange(of: equipmentLoadout) { _, _ in
            model.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.eligible.isEmpty {
            ContentUnavailableView("No Items to Equip", systemImage: "shippingbox")
        } else {
            ContentUnavailableView {
                Label("No Matching Items", systemImage: "line.3.horizontal.decrease")
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemsNoResults)
            } description: {
                Text("Try a different search or filter.")
            } actions: {
                Button("Clear Filters") { filter = ItemPickerFilter() }
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.clearItemFilters)
            }
        }
    }

    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Rarity", selection: $filter.rarity) {
                    Text("All Rarities").tag(nil as Rarity?)
                    ForEach([Rarity.unique, .astral, .basic]) { rarity in
                        Text(rarity.label).tag(Optional(rarity))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemRarityFilter)
                Picker("Keyword", selection: $filter.keyword) {
                    Text("All Keywords").tag(nil as Keyword?)
                    ForEach(model.keywords) { keyword in
                        Text(keyword.rawValue).tag(Optional(keyword))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemKeywordFilter)
                Button("Clear Filters") { filter = ItemPickerFilter() }
                    .disabled(!filter.isActive)
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.clearItemFilters)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .trinketTypography(filter.isActive ? .button : .body)
                    .foregroundStyle(filter.isActive ? TrinketDesign.Colors.accentEmphasized : .primary)
                    .accessibilityLabel("Filter Equipment")
                    .accessibilityValue(filter.isActive ? "Filters active" : "All equipment")
            }
            .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemFilter)
        }
    }

    private var equippedInSiblingSlotIDs: Set<String> {
        equipmentLoadout.itemIDs(inFamilyOf: slot)
            .subtracting([equipmentLoadout.itemID(for: slot)].compactMap(\.self))
    }
}
