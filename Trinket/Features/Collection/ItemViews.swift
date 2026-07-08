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
    @State private var searchText = ""
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16)
    ]

    var body: some View {
        let inventoryState = appState.inventory.current
        let items = filteredItems(from: inventoryState)

        ScrollView {
            if items.isEmpty {
                inventoryEmptyState(inventoryState: inventoryState)
                    .padding(TrinketDesign.Metrics.contentMargin)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(
                                    item: item,
                                    showsAffixCount: true,
                                    showsNewMarker: appState.showsCollectionNewMarker(forItem: item.id)
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
        .scrollDismissesKeyboard(.interactively)
        .trinketScreenBackground(.collection)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search items")
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
            let matchesSlot = selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || CollectionSearch.matchesItem(item, query: query, includeAffixes: true)

            return matchesSlot && matchesSearch
        }
    }

    @ViewBuilder
    private func inventoryEmptyState(inventoryState: PlayerInventoryState) -> some View {
        let isFilteredEmpty = !inventoryState.items.isEmpty

        if isFilteredEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "magnifyingglass",
                description: Text("Try a different search or filter.")
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
    var onPurchase: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    init(
        item: InventoryItem,
        purchasePrice: Int? = nil,
        canAfford: Bool = true,
        isPurchaseDisabled: Bool = false,
        onPurchase: (() -> Void)? = nil
    ) {
        self.item = item
        self.purchasePrice = purchasePrice
        self.canAfford = canAfford
        self.isPurchaseDisabled = isPurchaseDisabled
        self.onPurchase = onPurchase
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()

                        ItemCard(item: item, showsAffixCount: false, showsName: false)
                            .frame(maxWidth: 220)

                        Spacer()
                    }

                    Text(item.displayName)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .listRowBackground(Color.clear)
            }

            Section("Affixes") {
                ForEach(item.affixes.prefix(4)) { affix in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(affix.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        KeywordDescriptionText(text: affix.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(affix.sortedKeywords) { keyword in
                                Label(keyword.rawValue, systemImage: keyword.visualStyle.symbolName)
                                    .font(.caption)
                                    .foregroundStyle(keyword.visualStyle.color)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .trinketScreenBackground(.denseList)
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let purchasePrice, let onPurchase {
                Button {
                    onPurchase()
                } label: {
                    Text(canAfford ? "Buy for \(purchasePrice) Gold" : "Need \(purchasePrice) Gold")
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(canAfford ? Keyword.gold.visualStyle.color : .secondary)
                .disabled(!canAfford || isPurchaseDisabled)
                .accessibilityIdentifier(AccessibilityID.Shop.detailBuyButton)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            appState.markItemAsViewed(id: item.id)
        }
    }
}
