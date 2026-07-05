import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?

    var body: some View {
        searchContent
            .trinketScreenBackground(.denseList)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    ItemDetailView(item: item)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var searchContent: some View {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rosterState = appState.roster.current
        let inventoryState = appState.inventory.current

        if trimmedQuery.isEmpty {
            ContentUnavailableView(
                "Heroes, Pets, and Items",
                systemImage: "magnifyingglass"
            )
            .accessibilityIdentifier(AccessibilityID.Search.emptyState)
        } else {
            let results = getSearchResults(for: trimmedQuery, rosterState: rosterState, inventoryState: inventoryState)

            if results.isEmpty {
                ContentUnavailableView(
                    "No Results Found",
                    systemImage: "questionmark.magnifyingglass",
                    description: Text("No match for \"\(searchText)\".")
                )
                .accessibilityIdentifier(AccessibilityID.Search.noResults)
            } else {
                List {
                    combatantResultsSection(
                        title: "Heroes",
                        combatants: results.heroes,
                        rosterState: rosterState
                    )
                    combatantResultsSection(
                        title: "Pets",
                        combatants: results.pets,
                        rosterState: rosterState
                    )

                    if !results.items.isEmpty {
                        SearchResultSection(title: "Items", items: results.items) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(item: item, showsAffixCount: true)
                                    .collectionShelfCardWidth()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    @ViewBuilder
    private func combatantResultsSection(
        title: String,
        combatants: [Combatant],
        rosterState: PlayerRosterState
    ) -> some View {
        if !combatants.isEmpty {
            SearchResultSection(title: title, items: combatants) { combatant in
                combatantDetailLink(for: combatant, rosterState: rosterState)
            }
        }
    }

    private func combatantDetailLink(
        for combatant: Combatant,
        rosterState: PlayerRosterState
    ) -> some View {
        NavigationLink {
            CombatantDetailPane(
                appState: appState,
                combatant: combatant,
                rosterState: rosterState
            )
        } label: {
            CombatantCard(combatant: combatant)
                .collectionShelfCardWidth()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(combatant.name) collection card")
    }

    private struct SearchResults {
        let heroes: [Combatant]
        let pets: [Combatant]
        let items: [InventoryItem]

        var isEmpty: Bool {
            heroes.isEmpty && pets.isEmpty && items.isEmpty
        }
    }

    private func getSearchResults(
        for query: String,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState
    ) -> SearchResults {
        SearchResults(
            heroes: matchingCombatants(from: GameContent.heroes, query: query, rosterState: rosterState),
            pets: matchingCombatants(from: GameContent.pets, query: query, rosterState: rosterState),
            items: inventoryState.items.filter {
                $0.displayName.localizedCaseInsensitiveContains(query) ||
                    $0.baseType.name.localizedCaseInsensitiveContains(query)
            }
        )
    }

    private func matchingCombatants(
        from catalog: [Combatant],
        query: String,
        rosterState: PlayerRosterState
    ) -> [Combatant] {
        rosterState.configuredCombatants(catalog).filter {
            rosterState.isUnlocked($0) && $0.name.localizedCaseInsensitiveContains(query)
        }
    }
}

struct SearchResultSection<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content

    var body: some View {
        Section(title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: TrinketDesign.Metrics.collectionShelfCardSpacing) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, TrinketDesign.Metrics.shelfVerticalPadding)
            }
            .contentMargins(
                .horizontal,
                TrinketDesign.Metrics.collectionShelfHorizontalMargin,
                for: .scrollContent
            )
            .scrollTargetBehavior(.viewAligned)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
        }
    }
}
