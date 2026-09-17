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
    @State private var displayItems: [InventoryItem]
    @State private var searchText = ""
    @State private var readyItem: InventoryItem?
    @State private var detailArtworkLease: PreparedArtworkLease?
    @State private var requestedItem: InventoryItem?
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
        _displayItems = State(initialValue: initialItems.matching(ItemPickerFilter()))
    }

    var body: some View {
        let siblingIDs = equippedInSiblingSlotIDs

        ItemPickerSearchScope(readyItem: $readyItem, onReady: presentReadyItem) {
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
                            onSelect: { requestedItem = $0 },
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
                    let updated = model.matching(filter)
                    displayItems = updated
                    if let first = updated.first {
                        proxy.scrollTo(first.id, anchor: .top)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search equipment")
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
        .task(id: requestedItem) {
            guard let requestedItem else { return }
            let lease = await PreparedArtworkLease(names: [
                requestedItem.artReference?.imageName, requestedItem.artReference?.thumbnailImageName,
            ].compactMap(\.self))
            guard !Task.isCancelled, self.requestedItem == requestedItem else { return }
            detailArtworkLease = lease
            readyItem = requestedItem
            self.requestedItem = nil
        }
        .onChange(of: searchText) { _, query in
            if readyItem == nil, selectedItem == nil {
                filter.search = query
            }
        }
        .onChange(of: filter.search) { _, query in
            if readyItem == nil, selectedItem == nil {
                searchText = query
            }
        }
        .onChange(of: selectedItem) { previous, current in
            if previous != nil, current == nil {
                searchText = filter.search
                if readyItem == nil {
                    detailArtworkLease = nil
                }
            }
        }
        .onDisappear {
            if readyItem == nil, selectedItem == nil {
                requestedItem = nil
                detailArtworkLease = nil
            }
        }
        .onChange(of: inventoryItems, initial: true) { _, _ in
            model.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
            displayItems = model.matching(filter)
        }
        .onChange(of: equipmentLoadout) { _, _ in
            model.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
            displayItems = model.matching(filter)
        }
    }

    private func presentReadyItem() {
        guard let readyItem else { return }
        selectedItem = readyItem
        self.readyItem = nil
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

private struct ItemPickerSearchScope<Content: View>: View {
    @Environment(\.isSearching) private var isSearching
    @Environment(\.dismissSearch) private var dismissSearch
    @Binding var readyItem: InventoryItem?
    let onReady: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .onChange(of: readyItem?.id, initial: true) { _, _ in advance() }
            .onChange(of: isSearching) { _, _ in advance() }
    }

    private func advance() {
        guard readyItem != nil else { return }
        if isSearching {
            dismissSearch()
        } else {
            onReady()
        }
    }
}
