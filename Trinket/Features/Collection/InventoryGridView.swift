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
        case .trinket:
            .trinket
        }
    }
}

struct InventoryGridView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(OptionsStore.self) private var options
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?
    @State private var salvageSuccessCount = 0
    @Namespace private var zoomNamespace

    var body: some View {
        let inventoryState = playerSave.inventory
        let items = filteredItems(from: inventoryState)

        CollectionGridShell(items: items) { item in
            Button {
                selectedItem = item
            } label: {
                ItemCard(
                    item: item,
                    showsAffixCount: false
                )
            }
            .trinketQuietTapButtonStyle()
            .matchedTransitionSource(id: item.id, in: zoomNamespace)
            .accessibilityIdentifier("\(item.displayName) item card")
        } emptyView: {
            inventoryEmptyState(inventoryState: inventoryState)
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
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView.inventorySalvageDetail(item: item, saveStore: playerSave) { didSucceed in
                    if didSucceed {
                        salvageSuccessCount += 1
                    }
                    selectedItem = nil
                }
            }
            .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
            .trinketDetailSheet()
        }
        .trinketSensoryFeedback(
            .success,
            trigger: salvageSuccessCount,
            enabled: options.hapticsEnabled
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
                description: Text("Try a different filter.")
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryNoResults)
        } else {
            ContentUnavailableView(
                "No Items Yet",
                systemImage: "shippingbox",
                description: Text("Complete stages to earn gear for your heroes.")
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryEmptyState)
        }
    }
}

extension ItemDetailView {
    /// Collection inventory detail with salvage affordances for owned items.
    @MainActor
    static func inventorySalvageDetail(
        item: InventoryItem,
        saveStore: PlayerSaveStore,
        onFinished: @escaping (_ didSucceed: Bool) -> Void
    ) -> Self {
        let isOwned = saveStore.inventory.items.contains { $0.id == item.id }
        guard isOwned else {
            return Self(item: item)
        }
        let yields = ItemSalvage.yields(for: item)
        return Self(
            item: item,
            salvageYields: yields,
            salvageReceivableYields: saveStore.homestead.receivableAmounts(from: yields),
            equippedByName: saveStore.equippedCombatantName(for: item.id),
            onSalvage: {
                switch saveStore.salvageItem(id: item.id) {
                case .success:
                    true
                case .itemNotFound:
                    false
                case nil:
                    nil
                }
            },
            onSalvageFinished: onFinished
        )
    }
}
