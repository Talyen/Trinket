import SwiftUI
import TrinketContent
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

    private var unviewedCount: Int {
        switch kind {
        case .hero: appState.unviewedHeroCount
        case .pet: appState.unviewedPetCount
        }
    }

    private var markAllAccessibilityID: String {
        switch kind {
        case .hero: AccessibilityID.Collection.markAllHeroesSeen
        case .pet: AccessibilityID.Collection.markAllPetsSeen
        }
    }

    var body: some View {
        ScrollView {
            if combatants.isEmpty {
                ContentUnavailableView(
                    "Nothing to Collect",
                    systemImage: "person.3",
                    description: Text("Unlock heroes and pets by progressing through the journey.")
                )
                .padding(TrinketDesign.Metrics.contentMargin)
                .accessibilityIdentifier("Collection combatants empty state")
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(combatants) { combatant in
                            CollectionCombatantButton(
                                combatant: combatant,
                                isLocked: !appState.roster.current.isUnlocked(combatant),
                                cardWidth: nil,
                                showsNewMarker: appState.showsCollectionNewMarker(for: combatant.id)
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
        }
        .trinketScreenBackground(.collection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if unviewedCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Seen") {
                        appState.markAllCollectionCombatantsAsViewed(kind: kind)
                    }
                    .accessibilityIdentifier(markAllAccessibilityID)
                }
            }
        }
        .sheet(item: $selectedCombatant) { context in
            appState.rosterCombatantDetail(
                kind: context.kind,
                combatantID: context.combatantID
            )
            .trinketDetailSheet()
        }
    }
}
