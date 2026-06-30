import SwiftUI

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?
    @State private var selectedCombatant: CombatantCollectionDetailSelection?
    private let initialItemID: String?

    init(
        initialCombatantDetail: CombatantCollectionDetailSelection? = nil,
        initialItemID: String? = nil
    ) {
        _selectedCombatant = State(initialValue: initialCombatantDetail)
        self.initialItemID = initialItemID
    }

    var body: some View {
        let rosterState = appState.roster.current
        let inventoryState = appState.inventory.current

        ScrollView {
            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        HeroesGridView()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Heroes")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Heroes collection category")

                    horizontalShelf {
                        ForEach(rosterState.configuredCombatants(GameContent.heroes)) { combatant in
                            Button {
                                selectedCombatant = CombatantCollectionDetailSelection(kind: .hero, combatantID: combatant.id)
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        PetsGridView()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Pets")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Pets collection category")

                    horizontalShelf {
                        ForEach(rosterState.configuredCombatants(GameContent.pets)) { combatant in
                            Button {
                                selectedCombatant = CombatantCollectionDetailSelection(kind: .pet, combatantID: combatant.id)
                            } label: {
                                CombatantCard(combatant: combatant)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        InventoryGridView()
                    } label: {
                        HStack(spacing: 6) {
                            Text("Inventory")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Inventory collection category")

                    horizontalShelf {
                        ForEach(Array(inventoryState.items.prefix(12))) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                ItemCard(item: item, showsAffixCount: false)
                                    .frame(width: 130)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.displayName) item card")
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            guard selectedItem == nil,
                  let initialItemID,
                  let item = appState.inventory.current.item(matching: initialItemID)
            else { return }
            selectedItem = item
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $selectedCombatant) { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
    }

    private func horizontalShelf<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

}
