import SwiftUI
import TrinketDesignSystem

struct CollectionCombatantGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCombatant: CombatantDetailContext?

    let kind: CombatantDetailContext.Kind

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 16)
    ]

    private var title: String {
        switch kind {
        case .hero: "Heroes"
        case .pet: "Pets"
        }
    }

    private var combatants: [Combatant] {
        switch kind {
        case .hero: appState.roster.collectionHeroes
        case .pet: appState.roster.collectionPets
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(combatants) { combatant in
                        CollectionCombatantButton(
                            combatant: combatant,
                            isLocked: !appState.roster.current.isUnlocked(combatant),
                            cardWidth: nil
                        ) {
                            selectedCombatant = CombatantDetailContext(
                                kind: kind,
                                combatantID: combatant.id
                            )
                        }
                    }
                }
            }
            .padding(TrinketDesign.Metrics.contentMargin)
        }
        .trinketScreenBackground(.collection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCombatant) { context in
            CombatantDetailPane.Roster(context: context)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        }
    }
}
