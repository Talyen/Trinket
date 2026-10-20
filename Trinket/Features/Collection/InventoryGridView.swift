import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

enum CollectionItemCategory: String, CaseIterable, Identifiable {
    case basicGear = "Basic Gear"
    case astralGear = "Astral Gear"
    case uniqueGear = "Unique Gear"
    case trinkets = "Trinkets"

    var displayName: String {
        switch self {
        case .basicGear: String(localized: L10n.ui_inventorygridview_basic_gear_f4514)
        case .astralGear: String(localized: L10n.ui_inventorygridview_astral_gear_f6419)
        case .uniqueGear: String(localized: L10n.ui_inventorygridview_unique_gear_1404f)
        case .trinkets: String(localized: L10n.ui_inventorygridview_trinkets_e8322)
        }
    }

    var id: String {
        rawValue
    }

    var accessibilityIdentifier: String {
        switch self {
        case .basicGear: AccessibilityID.Collection.basicGearCategory
        case .astralGear: AccessibilityID.Collection.astralGearCategory
        case .uniqueGear: AccessibilityID.Collection.uniqueGearCategory
        case .trinkets: AccessibilityID.Collection.trinketsCategory
        }
    }

    func collectionItems(in inventory: [InventoryItem]) -> [InventoryItem] {
        includingCatalogItems(owned: inventory.filter(contains))
    }

    static func groupedCollectionItems(in inventory: [InventoryItem]) -> [Self: [InventoryItem]] {
        var grouped = Dictionary(grouping: inventory, by: Self.category)
        for category in allCases {
            grouped[category] = category.includingCatalogItems(owned: grouped[category] ?? [])
        }
        return grouped
    }

    private func includingCatalogItems(owned: [InventoryItem]) -> [InventoryItem] {
        let catalog: [InventoryItem] = switch self {
        case .trinkets: GameContent.trinketItems
        case .uniqueGear: GameContent.uniqueItems
        case .basicGear, .astralGear: []
        }
        guard !catalog.isEmpty else { return owned }
        guard !owned.isEmpty else { return catalog }
        let ownedTemplates = Set(owned.lazy.map(\.templateID))
        return owned + catalog.filter { !ownedTemplates.contains($0.templateID) }
    }

    func contains(_ item: InventoryItem) -> Bool {
        Self.category(for: item) == self
    }

    private static func category(for item: InventoryItem) -> Self {
        if item.isTrinket {
            return .trinkets
        }
        switch item.rarity {
        case .basic: return .basicGear
        case .astral: return .astralGear
        case .unique: return .uniqueGear
        }
    }
}

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapons"
    case armor = "Armor"
    case accessory = "Accessories"

    var displayName: String {
        switch self {
        case .all: String(localized: L10n.ui_inventorygridview_all_a52ac)
        case .weapon: String(localized: L10n.ui_inventorygridview_weapons_aafc7)
        case .armor: String(localized: L10n.ui_inventorygridview_armor_a5928)
        case .accessory: String(localized: L10n.ui_inventorygridview_accessories_b0864)
        }
    }

    var id: String {
        rawValue
    }

    var slot: ItemSlot? {
        switch self {
        case .all: nil
        case .weapon: .weapon
        case .armor: .armor
        case .accessory: .accessory
        }
    }
}

struct InventoryGridView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var selectedFilter: InventoryFilter = .all
    @State private var salvageDetail = SalvageDetailState()
    @State private var viewport = ArtworkViewportTracker<String>()

    let category: CollectionItemCategory

    var body: some View {
        let ownedIDs = Set(playerSave.inventory.items.lazy.map(\.id))
        let categoryItems = category.collectionItems(in: salvageDetail.presentationItems(in: playerSave.inventory.items))
        let items = if let slot = selectedFilter.slot {
            categoryItems.filter { $0.baseType.slot == slot }
        } else {
            categoryItems
        }

        CollectionGridShell(items: items) { item in
            SalvageItemButton(
                item: item,
                isLocked: !ownedIDs.contains(item.id),
                showsName: true,
                isPreparing: salvageDetail.requestedItem?.id == item.id,
                isRetiring: salvageDetail.transmutationEvent?.item.id == item.id,
                isTransmuting: salvageDetail.transmutationEvent?.item.id == item.id
                    && salvageDetail.transmutationEvent?.hasReturned == true,
            ) {
                salvageDetail.select(item, inventory: playerSave.inventory.items)
            }
            .onAppear { viewport.visibleIDs.insert(item.id) }
            .onDisappear { viewport.visibleIDs.remove(item.id) }
        } emptyView: {
            inventoryEmptyState(categoryItems: categoryItems)
        }
        .background {
            ArtworkViewportPrewarmObserver(
                entries: items.map {
                    ArtworkViewportEntry(
                        id: $0.id,
                        name: $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName,
                    )
                },
                viewport: viewport,
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
        }
        .trinketSoftTopScrollEdge()
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if category != .trinkets {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(
                            String(localized: L10n.ui_inventorygridview_filter_1_ae8dd("\(category.displayName)")),
                            selection: $selectedFilter,
                        ) {
                            ForEach(InventoryFilter.allCases) { filter in
                                GameLabel(filter.displayName)
                                    .tag(filter)
                                    .accessibilityIdentifier(
                                        AccessibilityID.Collection.gearFilterOption(
                                            slot: filter.slot?.rawValue.lowercased() ?? "all",
                                        ),
                                    )
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .trinketTypography(selectedFilter != .all ? .button : .body)
                            .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.accentEmphasized : .primary)
                            .accessibilityLabel(Text(L10n.ui_inventorygridview_filter_1_ae8dd("\(category.displayName)")))
                    }

                    .accessibilityIdentifier(AccessibilityID.Collection.gearFilter)
                }
            }
        }
        .salvageInventoryPresentation(
            salvageDetail: $salvageDetail,
            hapticsEnabled: options.hapticsEnabled,
        )
    }

    @MainActor
    @ViewBuilder
    private func inventoryEmptyState(categoryItems: [InventoryItem]) -> some View {
        let isFilteredEmpty = !categoryItems.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                String(localized: L10n.ui_inventorygridview_no_matching_items_cef58),
                systemImage: "line.3.horizontal.decrease",
                description: Text(L10n.ui_inventorygridview_try_a_different_filter_cabc7),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsNoResults)
        } else {
            ContentUnavailableView(
                String(localized: L10n.ui_inventorygridview_no_1_yet_c5f22("\(category.displayName)")),
                systemImage: "shippingbox",
                description: Text(L10n.ui_inventorygridview_your_1_will_appear_here_when_you_collect_them_37243("\(category.displayName)")),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsEmptyState)
        }
    }
}
