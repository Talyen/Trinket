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

    func contains(_ item: InventoryItem) -> Bool {
        if item.isTrinket {
            return self == .trinkets
        }
        switch item.rarity {
        case .basic: return self == .basicGear
        case .astral: return self == .astralGear
        case .unique: return self == .uniqueGear
        }
    }
}

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapons"
    case armor = "Armor"
    case accessory = "Accessories"

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
    @State private var visibleItemIDs: Set<String> = []

    let category: CollectionItemCategory

    var body: some View {
        let categoryItems = playerSave.inventory.items.filter(category.contains)
        let items = categoryItems.filter { item in
            selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
        }

        CollectionGridShell(items: items) { item in
            SalvageItemButton(
                item: item,
                showsName: true,
            ) {
                salvageDetail.select(item)
            }
            .onAppear { visibleItemIDs.insert(item.id) }
            .onDisappear { visibleItemIDs.remove(item.id) }
        } emptyView: {
            inventoryEmptyState(categoryItems: categoryItems)
        }
        .onChange(of: items.map(\.id)) { _, _ in
            visibleItemIDs.formIntersection(items.lazy.map(\.id))
        }
        .task(id: visibleItemIDs) {
            await ArtworkViewportPrewarm.prewarm(
                orderedItems: items,
                visibleIDs: visibleItemIDs,
                currentVisibleIDs: { visibleItemIDs },
                thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if category != .trinkets {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(InventoryFilter.allCases) { filter in
                            Toggle(filter.rawValue, isOn: Binding(
                                get: { selectedFilter == filter },
                                set: { isSelected in
                                    if isSelected {
                                        selectedFilter = filter
                                    }
                                },
                            ))
                            .accessibilityIdentifier(
                                AccessibilityID.Collection.gearFilterOption(
                                    slot: filter.slot?.rawValue.lowercased() ?? "all",
                                ),
                            )
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .trinketTypography(selectedFilter != .all ? .button : .body)
                            .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.accentEmphasized : .primary)
                            .accessibilityLabel("Filter \(category.rawValue)")
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

    @ViewBuilder
    private func inventoryEmptyState(categoryItems: [InventoryItem]) -> some View {
        let isFilteredEmpty = !categoryItems.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "line.3.horizontal.decrease",
                description: Text("Try a different filter."),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsNoResults)
        } else {
            ContentUnavailableView(
                "No \(category.rawValue) Yet",
                systemImage: "shippingbox",
                description: Text("Your \(category.rawValue.lowercased()) will appear here when you collect them."),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsEmptyState)
        }
    }
}

extension ItemDetailView {
    @MainActor
    static func inventorySalvageDetail(
        item: InventoryItem,
        saveStore: PlayerSaveStore,
        onFinished: @escaping (ItemSalvageActionResult) -> Void,
    ) -> Self {
        let isOwned = saveStore.inventory.items.contains { $0.id == item.id }
        guard isOwned else {
            return Self(item: item)
        }
        guard ItemSalvage.isEligible(item) else {
            return Self(item: item)
        }
        let yields = ItemSalvage.yields(for: item)
        return Self(
            item: item,
            salvageYields: yields,
            equippedByName: saveStore.roster.equippedCombatantName(for: item.id),
            onSalvage: { () -> ItemSalvageActionResult in
                let result = withAnimation(TrinketMotion.Reward.stateChange) {
                    saveStore.salvageItem(id: item.id)
                }
                switch result {
                case let .success(yields):
                    return .success(yields: yields)
                case .itemNotFound:
                    return .itemNotFound
                case .ineligible:
                    return .itemNotFound
                case nil:
                    return .persistenceFailure
                }
            },
            onSalvageFinished: onFinished,
        )
    }
}
