import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct ItemSlotPickerView: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    let slot: ItemSlot
    let equipmentLoadout: EquipmentLoadout
    let inventoryItems: [InventoryItem]
    let onEquip: (InventoryItem) -> Void
    let onUnequip: () -> Void

    @State private var model: ItemPickerItems
    @State private var filter = ItemPickerFilter()
    @State private var displayItems: [InventoryItem]
    @State private var searchText = ""
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var readyItem: InventoryItem?
    @State private var detailArtworkLease: PreparedArtworkLease?
    @State private var requestedItem: InventoryItem?
    @State private var selectedItem: InventoryItem?
    @State private var equipmentOwners = EquipmentOwnerIndex()

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
        let ownerNames = equipmentOwners.names(for: playerSave.roster.equipmentLoadouts)
        ItemPickerSearchScope(readyItem: $readyItem, onReady: presentReadyItem) {
            VStack(spacing: 0) {
                if filter.isActive {
                    Text(L10n.ui_itemslotpickerview_1_of_2_items_e86cf("\(displayItems.count)", "\(model.eligible.count)"))
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
                            .overlay(alignment: .topLeading) {
                                equipmentBadge(for: item, ownerNames: ownerNames)
                            }
                        },
                    )
                    .scrollPosition($scrollPosition)
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemGrid(slot.displayName))
                }
            }
            .onChange(of: filter) { _, _ in
                displayItems = model.matching(filter)
                // Newly filtered item IDs may not have lazy-layout geometry yet.
                scrollPosition.scrollTo(edge: .top)
            }
        }
        .searchable(text: $searchText, prompt: String(localized: L10n.ui_itemslotpickerview_search_equipment_869c1))
        .toolbar { filterToolbar }
        .navigationTitle(Text(equipTitle))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            let isEquipped = equipmentLoadout.itemID(for: slot) == item.id
            ItemDetailView(
                item: item,
                primaryActionTitle: actionTitle(for: item),
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
        .onChange(of: inventoryItems) { _, _ in updateItems() }
        .onChange(of: equipmentLoadout) { _, _ in updateItems() }
    }

    private func updateItems() {
        model.update(inventory: inventoryItems, loadout: equipmentLoadout, slot: slot)
        displayItems = model.matching(filter)
    }

    private func presentReadyItem() {
        guard let readyItem else { return }
        selectedItem = readyItem
        self.readyItem = nil
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.eligible.isEmpty {
            ContentUnavailableView(String(localized: L10n.ui_itemslotpickerview_no_items_to_equip_c1b35), systemImage: "shippingbox")
        } else {
            ContentUnavailableView {
                Label(String(localized: L10n.ui_itemslotpickerview_no_matching_items_cef58), systemImage: "line.3.horizontal.decrease")
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemsNoResults)
            } description: {
                Text(L10n.ui_itemslotpickerview_try_a_different_search_or_filter_bf470)
            } actions: {
                Button(String(localized: L10n.ui_itemslotpickerview_clear_filters_57765)) { filter = ItemPickerFilter() }
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.clearItemFilters)
            }
        }
    }

    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if slot != .trinket {
                    Picker(String(localized: L10n.ui_itemslotpickerview_rarity_feddc), selection: $filter.rarity) {
                        Text(L10n.ui_itemslotpickerview_all_rarities_3b733).tag(nil as Rarity?)
                        ForEach([Rarity.unique, .astral, .basic]) { rarity in
                            GameLabel(rarity.label).tag(Optional(rarity))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemRarityFilter)
                }
                Picker(String(localized: L10n.ui_itemslotpickerview_keyword_a6680), selection: $filter.keyword) {
                    Text(L10n.ui_itemslotpickerview_all_keywords_db832).tag(nil as Keyword?)
                    ForEach(model.keywords) { keyword in
                        GameLabel(keyword.rawValue).tag(Optional(keyword))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemKeywordFilter)
                Button(String(localized: L10n.ui_itemslotpickerview_clear_filters_57765)) { filter = ItemPickerFilter() }
                    .disabled(!filter.isActive)
                    .accessibilityIdentifier(AccessibilityID.LoadoutPicker.clearItemFilters)
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .trinketTypography(filter.isActive ? .button : .body)
                    .foregroundStyle(filter.isActive ? TrinketDesign.Colors.accentEmphasized : .primary)
                    .accessibilityLabel(Text(L10n.ui_itemslotpickerview_filter_equipment_3b068))
                    .accessibilityValue(filter
                        .isActive ? String(localized: L10n.ui_itemslotpickerview_filters_active_1334e) :
                        String(localized: L10n.ui_itemslotpickerview_all_equipment_b79c2))
            }
            .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemFilter)
        }
    }

    private func otherWearerName(for item: InventoryItem) -> String? {
        guard !equipmentLoadout.itemIDsBySlot.values.contains(item.id) else { return nil }
        return equipmentOwners.names(for: playerSave.roster.equipmentLoadouts)[item.id]
    }

    private var equipTitle: LocalizedStringResource {
        switch slot {
        case .weapon, .secondaryWeapon: L10n.ui_itemslotpickerview_equip_weapon
        case .armor: L10n.ui_itemslotpickerview_equip_armor
        case .accessory, .secondaryAccessory: L10n.ui_itemslotpickerview_equip_accessory
        case .trinket, .secondaryTrinket: L10n.ui_itemslotpickerview_equip_trinket
        }
    }

    private var unequipTitle: LocalizedStringResource {
        switch slot {
        case .weapon, .secondaryWeapon: L10n.ui_itemslotpickerview_unequip_weapon
        case .armor: L10n.ui_itemslotpickerview_unequip_armor
        case .accessory, .secondaryAccessory: L10n.ui_itemslotpickerview_unequip_accessory
        case .trinket, .secondaryTrinket: L10n.ui_itemslotpickerview_unequip_trinket
        }
    }

    private func actionTitle(for item: InventoryItem) -> String {
        if equipmentLoadout.itemID(for: slot) == item.id {
            return String(localized: unequipTitle)
        }
        if let wearer = otherWearerName(for: item) {
            return String(localized: L10n.ui_itemslotpickerview_move_from_1_7bb90("\(wearer)"))
        }
        return String(localized: equipTitle)
    }

    @ViewBuilder
    private func equipmentBadge(for item: InventoryItem, ownerNames: [String: String]) -> some View {
        let isEquippedHere = equipmentLoadout.itemIDsBySlot.values.contains(item.id)
        let otherWearer = isEquippedHere ? nil : ownerNames[item.id]
        if isEquippedHere || otherWearer != nil {
            Image(systemName: isEquippedHere ? "checkmark" : "person.fill")
                .trinketTypography(.badge)
                .foregroundStyle(isEquippedHere ? TrinketDesign.Colors.accentEmphasized : .primary)
                .frame(width: 24, height: 24)
                .background(TrinketDesign.Colors.panel, in: Circle())
                .padding(TrinketDesign.Spacing.tight)
                .accessibilityLabel(otherWearer
                    .map { String(localized: L10n.ui_itemslotpickerview_equipped_by_1_a51ee("\($0)")) } ??
                    String(localized: L10n.ui_itemslotpickerview_equipped_by_this_combatant_6179d))
        }
    }
}

@MainActor
private final class EquipmentOwnerIndex {
    private var loadouts: [String: EquipmentLoadout]?
    private var ownerNames: [String: String] = [:]

    func names(for current: [String: EquipmentLoadout]) -> [String: String] {
        guard loadouts != current else { return ownerNames }
        var names: [String: String] = [:]
        for (combatantID, loadout) in current {
            let name = GameContent.combatant(matching: combatantID)?.name ?? combatantID
            for itemID in loadout.itemIDsBySlot.values where names[itemID] == nil {
                names[itemID] = name
            }
        }
        loadouts = current
        ownerNames = names
        return names
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
