import Observation
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
    @State private var viewport = InventoryViewportTracker()

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
            InventoryArtworkPrewarmObserver(
                entries: items.map {
                    .init(id: $0.id, name: $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName)
                },
                viewport: viewport,
            )
        }
        .trinketSoftTopScrollEdge()
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if category != .trinkets {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter \(category.rawValue)", selection: $selectedFilter) {
                            ForEach(InventoryFilter.allCases) { filter in
                                Text(filter.rawValue)
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

    @MainActor
    @ViewBuilder
    private func inventoryEmptyState(categoryItems: [InventoryItem]) -> some View {
        let isFilteredEmpty = !categoryItems.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "line.3.horizontal.decrease",
                description: Text("Try a different filter"),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsNoResults)
        } else {
            ContentUnavailableView(
                "No \(category.rawValue) Yet",
                systemImage: "shippingbox",
                description: Text("Your \(category.rawValue.lowercased()) will appear here when you collect them"),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.itemsEmptyState)
        }
    }
}

@MainActor
@Observable
private final class InventoryViewportTracker {
    var visibleIDs: Set<String> = []
}

private struct InventoryArtworkPrewarmObserver: View {
    struct Entry: Identifiable, Equatable {
        let id: String
        let name: String?
    }

    private struct Key: Equatable {
        let visibleIDs: Set<String>
        let entries: [Entry]
    }

    let entries: [Entry]
    @State private var window = ArtworkViewportPrewarm.Window<Entry>(orderedItems: [])
    let viewport: InventoryViewportTracker

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onChange(of: entries, initial: true) { _, entries in
                window = ArtworkViewportPrewarm.Window(orderedItems: entries)
                viewport.visibleIDs.formIntersection(entries.map(\.id))
            }
            .task(id: Key(visibleIDs: viewport.visibleIDs, entries: window.orderedItems)) {
                await ArtworkViewportPrewarm.prewarm(
                    window: window,
                    visibleIDs: viewport.visibleIDs,
                    currentVisibleIDs: { viewport.visibleIDs },
                    thumbnailName: { $0.name },
                    prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                    estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
                )
            }
    }
}
