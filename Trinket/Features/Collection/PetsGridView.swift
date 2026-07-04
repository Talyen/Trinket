import SwiftUI

struct PetsGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCombatant: CombatantCollectionDetailSelection?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(appState.roster.collectionPets) { combatant in
                        CollectionCombatantButton(
                            combatant: combatant,
                            isLocked: !appState.roster.isUnlocked(combatant),
                            cardWidth: nil
                        ) {
                            selectedCombatant = CombatantCollectionDetailSelection(
                                kind: .pet,
                                combatantID: combatant.id
                            )
                        }
                    }
                }
            }
            .padding(TrinketDesign.Metrics.contentMargin)
        }
        .background(TrinketDesign.Colors.appBackground)
        .navigationTitle("Pets")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCombatant) { selection in
            CombatantCollectionDetailSheet(selection: selection)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
    }
}
