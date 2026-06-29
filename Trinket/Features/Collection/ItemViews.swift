import SwiftUI

enum InventoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weapon = "Weapon"
    case armor = "Armor"
    case trinket = "Trinket"

    var id: String { rawValue }

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
    @Binding var inventoryState: PlayerInventoryState
    @State private var searchText = ""
    @State private var selectedFilter: InventoryFilter = .all
    @State private var selectedItem: InventoryItem?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredItems) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            ItemCard(item: item, showsAffixCount: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(item.displayName) item card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var filteredItems: [InventoryItem] {
        inventoryState.items.filter { item in
            let matchesSlot = selectedFilter.slot.map { $0 == item.baseType.slot } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(query)
                || item.baseType.name.localizedCaseInsensitiveContains(query)
                || item.affixes.contains { affix in
                    affix.title.localizedCaseInsensitiveContains(query)
                        || affix.description.localizedCaseInsensitiveContains(query)
                }

            return matchesSlot && matchesSearch
        }
    }
}

struct ItemDetailView: View {
    let item: InventoryItem
    @Environment(\.dismiss) private var dismiss

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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(affix.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle(item.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
