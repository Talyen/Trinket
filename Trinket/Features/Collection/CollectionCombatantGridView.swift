import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionCombatantGridView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCombatant: CombatantDetailContext?

    let kind: CombatantDetailContext.Kind

    private let columns = TrinketDesign.Metrics.collectionGridItems

    private var title: String {
        switch kind {
        case .hero: "Heroes"
        case .companion: "Companions"
        }
    }

    private var combatants: [Combatant] {
        switch kind {
        case .hero: appState.roster.collectionHeroes
        case .companion: appState.roster.collectionCompanions
        }
    }

    var body: some View {
        ScrollView {
            if combatants.isEmpty {
                ContentUnavailableView(
                    "Nothing to Collect",
                    systemImage: "person.3",
                    description: Text("Unlock heroes and companions by progressing through the journey.")
                )
                .padding(TrinketDesign.Metrics.contentMargin)
                .accessibilityIdentifier("Collection combatants empty state")
            } else {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.sectionSpacing) {
                    LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.largeSpacing) {
                        ForEach(combatants) { combatant in
                            CollectionCombatantButton(
                                combatant: combatant,
                                isLocked: !appState.roster.isUnlocked(combatant),
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
        }
        .trinketScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCombatant) { context in
            NavigationStack {
                appState.rosterCombatantDetail(
                    kind: context.kind,
                    combatantID: context.combatantID
                )
            }
            .trinketDetailSheet()
        }
    }
}
