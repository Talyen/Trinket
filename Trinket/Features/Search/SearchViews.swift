import SwiftUI

struct SearchView: View {
    @Binding var rosterState: PlayerRosterState
    @Binding var inventoryState: PlayerInventoryState
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

        if trimmedQuery.isEmpty {
            ContentUnavailableView(
                "Heroes, Pets, and Items",
                systemImage: "magnifyingglass"
            )
        } else {
            let results = getSearchResults(for: trimmedQuery)

            if results.isEmpty {
                ContentUnavailableView(
                    "No Results Found",
                    systemImage: "questionmark.magnifyingglass",
                    description: Text("No match for \"\(searchText)\" .")
                )
            } else {
                List {
                    if !results.heroes.isEmpty {
                        SearchResultSection(title: "Heroes", items: results.heroes) { combatant in
                            NavigationLink {
                                CombatantCollectionDetailView(
                                    combatant: combatant,
                                    progression: rosterState.progression(for: combatant),
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
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
                                    loadout: loadoutBinding(for: combatant),
                                    equipmentLoadout: equipmentLoadoutBinding(for: combatant),
                                    inventoryState: $inventoryState
                                )
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
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
                                    .frame(width: 130)
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

    private func getSearchResults(for query: String) -> SearchResults {
        let matchingHeroes = rosterState.configuredCombatants(GameContent.heroes).filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingPets = rosterState.configuredCombatants(GameContent.pets).filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        let matchingItems = inventoryState.items.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.baseType.name.localizedCaseInsensitiveContains(query)
        }

        return SearchResults(heroes: matchingHeroes, pets: matchingPets, items: matchingItems)
    }

    private func loadoutBinding(for combatant: Combatant) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { loadout in
            rosterState.setLoadout(loadout, for: combatant)
        }
    }

    private func equipmentLoadoutBinding(for combatant: Combatant) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { loadout in
            rosterState.setEquipmentLoadout(loadout, for: combatant)
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
                HStack(spacing: 16) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
        }
    }
}
