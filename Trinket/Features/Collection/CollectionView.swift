import SwiftUI

struct CollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedItem: InventoryItem?

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
                        ForEach(inventoryState.items) { item in
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
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailView(item: item)
            }
            .presentationDetents([.large])
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
