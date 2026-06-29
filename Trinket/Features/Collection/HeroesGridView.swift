import SwiftUI

struct HeroesGridView: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        let rosterState = appState.roster.current
        let inventoryState = appState.inventory.current

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) collection card")
                    }
                }
            }
            .padding(20)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Heroes")
        .navigationBarTitleDisplayMode(.large)
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
