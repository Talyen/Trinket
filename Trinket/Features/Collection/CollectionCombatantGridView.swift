import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CollectionCombatantGridView: View {
    @Environment(AppState.self) private var appState

    let kind: CombatantDetailContext.Kind
    /// Binding owned by CollectionView (the NavigationStack root).
    /// Tap selects here; the sheet is presented by the root, avoiding tab bar blocking.
    @Binding var selectedCombatant: CombatantDetailContext?

    init(kind: CombatantDetailContext.Kind, selectedCombatant: Binding<CombatantDetailContext?> = .constant(nil)) {
        self.kind = kind
        _selectedCombatant = selectedCombatant
    }

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
                                cardWidth: nil
                            ) {
                                selectedCombatant = CombatantDetailContext(
                                    kind: kind,
                                    combatantID: combatant.id
                                )
                            }
                            .accessibilityIdentifier("\(combatant.name) collection card")
                        }
                    }
                }
                .padding(TrinketDesign.Metrics.contentMargin)
            }
        }
        .trinketScreenBackground(.collection)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        // No .sheet here — the sheet is owned by CollectionView (NavigationStack root).
    }
}
