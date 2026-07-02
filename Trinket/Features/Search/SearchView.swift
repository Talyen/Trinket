import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?

    var body: some View {
        searchContent
            .background(TrinketDesign.Colors.appBackground)
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
                    description: Text("No match for \"\(searchText)\" .")
                )
                .accessibilityIdentifier(AccessibilityID.Search.noResults)
            } else {
                List {
                    if !results.heroes.isEmpty {
                        SearchResultSection(title: "Heroes", items: results.heroes) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    inventoryState: inventoryState,
                                    loadout: loadoutBinding(for: combatant, in: rosterState),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant, in: rosterState)
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .collectionShelfCardWidth()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }

                    if !results.pets.isEmpty {
                        SearchResultSection(title: "Pets", items: results.pets) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    inventoryState: inventoryState,
                                    loadout: loadoutBinding(for: combatant, in: rosterState),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant, in: rosterState)
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .collectionShelfCardWidth()
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }

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
            }
        }
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
        let matchingHeroes = rosterState.configuredCombatants(GameContent.heroes).filter {
            rosterState.isUnlocked($0) && $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingPets = rosterState.configuredCombatants(GameContent.pets).filter {
            rosterState.isUnlocked($0) && $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingItems = inventoryState.items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.baseType.name.localizedCaseInsensitiveContains(query)
        }

        return SearchResults(heroes: matchingHeroes, pets: matchingPets, items: matchingItems)
    }

    private func loadoutBinding(for combatant: Combatant, in rosterState: PlayerRosterState) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setLoadout(newValue, for: combatant)
            appState.roster.current = updated
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant, in rosterState: PlayerRosterState) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setEquipmentLoadout(newValue, for: combatant)
            appState.roster.current = updated
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
                .padding(.vertical, 4)
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
