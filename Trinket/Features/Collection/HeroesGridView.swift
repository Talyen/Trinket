import SwiftUI

struct HeroesGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCombatant: CombatantCollectionDetailSelection?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        let rosterState = appState.roster.current

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(rosterState.configuredCombatants(GameContent.heroes)) { combatant in
                        Button {
                            selectedCombatant = CombatantCollectionDetailSelection(
                                kind: .hero,
                                combatantID: combatant.id
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
        .sheet(item: $selectedCombatant) { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
    }
}
