import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapon"
    case armor = "Armor"
    case accessory = "Accessory"
    case trinket = "Trinket"

    var id: String {
        rawValue
    }

    var slot: ItemSlot? {
        switch self {
        case .all:
            nil
        case .weapon:
            .weapon
        case .armor:
            .armor
        case .accessory:
            .accessory
        case .trinket:
            .trinket
        }
    }
}

struct InventoryGridView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var selectedFilter: InventoryFilter = .all
    @State private var salvageDetail = SalvageDetailState()
    @State private var visibleItemIDs: Set<String> = []

    var body: some View {
        let inventoryState = playerSave.inventory
        let items = filteredItems(from: inventoryState)

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
            inventoryEmptyState(inventoryState: inventoryState)
        }
        .onChange(of: items.map(\.id)) { _, _ in
            visibleItemIDs.formIntersection(items.lazy.map(\.id))
        }
        .task(id: visibleItemIDs) {
            let snapshot = visibleItemIDs
            try? await Task.sleep(for: ArtworkViewportPrewarm.viewportDebounceInterval)
            guard !Task.isCancelled, snapshot == visibleItemIDs else { return }
            let names = ArtworkViewportPrewarm.windowNames(
                orderedItems: items,
                visibleIDs: snapshot,
                thumbnailName: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
                prefetchRows: ArtworkViewportPrewarm.defaultPrefetchRows,
                estimatedColumns: ArtworkViewportPrewarm.collectionEstimatedColumns,
            )
            guard !names.isEmpty else { return }
            await PreparedArtworkCache.shared.prepare(names: names)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(InventoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .trinketTypography(selectedFilter != .all ? .button : .body)
                        .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.accentEmphasized : .primary)
                }

                .accessibilityIdentifier("Inventory filter")
            }
        }
        .salvageInventoryPresentation(
            salvageDetail: $salvageDetail,
            hapticsEnabled: options.hapticsEnabled,
        )
    }

    private func filteredItems(from inventoryState: PlayerInventoryState) -> [InventoryItem] {
        inventoryState.items.filter { item in
            selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
        }
    }

    @ViewBuilder
    private func inventoryEmptyState(inventoryState: PlayerInventoryState) -> some View {
        let isFilteredEmpty = !inventoryState.items.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "line.3.horizontal.decrease",
                description: Text("Try a different filter."),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryNoResults)
        } else {
            ContentUnavailableView(
                "No Items Yet",
                systemImage: "shippingbox",
                description: Text("Complete stages to earn gear for your heroes."),
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryEmptyState)
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
