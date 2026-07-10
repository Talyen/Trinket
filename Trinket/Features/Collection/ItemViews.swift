import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
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
            return nil
        case .weapon:
            return .weapon
        case .armor:
            return .armor
        case .trinket:
            return .trinket
        }
    }
}

struct InventoryGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?

    private let columns = TrinketDesign.Metrics.collectionGridItems

    var body: some View {
        let inventoryState = appState.inventory.current
        let items = filteredItems(from: inventoryState)

        ScrollView {
            if items.isEmpty {
                inventoryEmptyState(inventoryState: inventoryState)
                    .padding(TrinketDesign.Metrics.contentMargin)
            } else {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionSpacing) {
                    LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: true
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
                .padding(TrinketDesign.Metrics.contentMargin)
            }
        }
        .trinketScreenBackground(.collection)
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
                        .font(.body.weight(selectedFilter != .all ? .semibold : .regular))
                        .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.cardArtAccent : .primary)
                }
                .accessibilityLabel("Filter")
                .accessibilityIdentifier("Inventory filter")
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .trinketDetailSheet()
        }
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

struct ItemDetailView: View {
    let item: InventoryItem
    var purchasePrice: Int?
    var canAfford: Bool = true
    var isPurchaseDisabled: Bool = false
    /// When set, replaces the default Buy / Need Gold label (e.g. Sold Out).
    var purchaseButtonTitleOverride: String?
    var onPurchase: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    init(
        item: InventoryItem,
        purchasePrice: Int? = nil,
        canAfford: Bool = true,
        isPurchaseDisabled: Bool = false,
        purchaseButtonTitleOverride: String? = nil,
        onPurchase: (() -> Void)? = nil
    ) {
        self.item = item
        self.purchasePrice = purchasePrice
        self.canAfford = canAfford
        self.isPurchaseDisabled = isPurchaseDisabled
        self.purchaseButtonTitleOverride = purchaseButtonTitleOverride
        self.onPurchase = onPurchase
    }

    private var purchaseButtonTitle: String {
        if let purchaseButtonTitleOverride {
            return purchaseButtonTitleOverride
        }
        guard let purchasePrice else { return "Buy" }
        return canAfford ? "Buy for \(purchasePrice) Gold" : "Need \(purchasePrice) Gold"
    }

    var body: some View {
        DetailHeroScrollShell(
            title: item.displayName,
            showsDoneButton: true,
            onDone: { dismiss() },
            header: {
                ItemHeroHeader(item: item, baseHeight: $0, overscroll: $1)
                    .accessibilityIdentifier("\(item.displayName) detail hero header")
            },
            bodyContent: {
                DetailSection("Affixes") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(item.affixes.prefix(4)) { affix in
                            KeywordDescriptionText(text: affix.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        )
        .safeAreaInset(edge: .bottom) {
            if let purchasePrice, let onPurchase {
                Button {
                    onPurchase()
                } label: {
                    Text(purchaseButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(canAfford && !isPurchaseDisabled ? Keyword.gold.visualStyle.color : .secondary)
                .disabled(!canAfford || isPurchaseDisabled)
                .accessibilityIdentifier(AccessibilityID.Shop.detailBuyButton)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, 12)
            }
        }
    }
}
