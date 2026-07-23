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
    @Environment(AppState.self) private var appState
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?
    @Namespace private var zoomNamespace

    var body: some View {
        let inventoryState = appState.inventory
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
                        .foregroundStyle(selectedFilter != .all ? TrinketDesign.Colors.cardArtAccent : .primary)
                }

                .accessibilityIdentifier("Inventory filter")
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .navigationTransition(.zoom(sourceID: item.id, in: zoomNamespace))
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
    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem
    var purchasePrice: Int?
    var canAfford: Bool = true
    var isPurchaseDisabled: Bool = false
    /// When set, replaces the default Buy / Need Gold label (e.g. Sold Out).
    var purchaseButtonTitleOverride: String?
    var onPurchase: (() -> Void)?
    var primaryActionTitle: String?
    var primaryActionAccessibilityID: String?
    var dismissAfterPrimaryAction = false
    var onPrimaryAction: (() -> Void)?

    init(
        item: InventoryItem,
        purchasePrice: Int? = nil,
        canAfford: Bool = true,
        isPurchaseDisabled: Bool = false,
        purchaseButtonTitleOverride: String? = nil,
        onPurchase: (() -> Void)? = nil,
        primaryActionTitle: String? = nil,
        primaryActionAccessibilityID: String? = nil,
        dismissAfterPrimaryAction: Bool = false,
        onPrimaryAction: (() -> Void)? = nil
    ) {
        self.item = item
        self.purchasePrice = purchasePrice
        self.canAfford = canAfford
        self.isPurchaseDisabled = isPurchaseDisabled
        self.purchaseButtonTitleOverride = purchaseButtonTitleOverride
        self.onPurchase = onPurchase
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityID = primaryActionAccessibilityID
        self.dismissAfterPrimaryAction = dismissAfterPrimaryAction
        self.onPrimaryAction = onPrimaryAction
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
            header: {
                DetailHeroHeader(
                    eyebrow: item.rarity.label.uppercased(),
                    title: item.displayName,
                    baseHeight: $0,
                    overscroll: $1
                ) {
                    ItemArtwork(item: item)
                }
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.itemDetail(item.id))
            },
            bodyContent: {
                DetailSection("Traits") {
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        ForEach(item.affixes.prefix(4)) { affix in
                            DetailTraitRow(description: affix.description)
                        }
                    }
                }
            }
        )
        .safeAreaInset(edge: .bottom) {
            if let primaryActionTitle, let onPrimaryAction {
                Button(primaryActionTitle) {
                    onPrimaryAction()
                    if dismissAfterPrimaryAction {
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton()
                .accessibilityIdentifier(primaryActionAccessibilityID ?? primaryActionTitle)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            } else if purchasePrice != nil, let onPurchase {
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
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
        }
    }
}
