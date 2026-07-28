import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct CollectionCombatantGridView: View {
    @Environment(PlayerSaveStore.self) private var appState
    @Environment(OptionsStore.self) private var options
    @State private var selectedCombatant: CombatantDetailContext?
    @Namespace private var zoomNamespace

    let kind: CombatantDetailContext.Kind

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
        CollectionGridShell(items: combatants) { combatant in
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
            .matchedTransitionSource(id: combatant.id, in: zoomNamespace)
        } emptyView: {
            ContentUnavailableView(
                "Nothing to Collect",
                systemImage: "person.3",
                description: Text("Unlock heroes and companions by progressing through the journey.")
            )
            .accessibilityIdentifier("Collection combatants empty state")
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCombatant) { context in
            NavigationStack {
                RosterCombatantDetailView(
                    kind: context.kind,
                    combatantID: context.combatantID,
                    hapticsEnabled: options.hapticsEnabled,
                    effectsVolume: options.effectsVolume
                )
            }
            .navigationTransition(.zoom(sourceID: context.combatantID, in: zoomNamespace))
            .trinketDetailSheet()
        }
    }
}
