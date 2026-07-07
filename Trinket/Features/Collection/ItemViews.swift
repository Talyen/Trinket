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
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemCard(item: item, showsAffixCount: true)
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
    }

    private func filteredItems(from inventoryState: PlayerInventoryState) -> [InventoryItem] {
        inventoryState.items.filter { item in
            let matchesSlot = selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(query)
                || item.baseType.name.localizedCaseInsensitiveContains(query)
                || item.affixes.contains { affix in
                    affix.title.localizedCaseInsensitiveContains(query)
                        || affix.description.localizedCaseInsensitiveContains(query)
                        || affix.keywords.contains { keyword in
                            keyword.rawValue.localizedCaseInsensitiveContains(query)
                        }
                }

            return matchesSlot && matchesSearch
        }
    }

    @ViewBuilder
    private func inventoryEmptyState(inventoryState: PlayerInventoryState) -> some View {
        if !inventoryState.items.isEmpty {
            ContentUnavailableView(
                "No Matching Items",
                systemImage: "magnifyingglass",
                description: Text("Try a different search or filter.")
            )
            .accessibilityIdentifier(AccessibilityID.Collection.inventoryNoResults)
        }
    }
}

struct ItemDetailView: View {
    let item: InventoryItem

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
    }
}
