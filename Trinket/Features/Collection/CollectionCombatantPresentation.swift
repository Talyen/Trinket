import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct CollectionCombatantGridView: View {
    @Environment(\.requestFullGameOffer) private var requestOffer
    @Environment(PlayerSaveStore.self) private var playerSave
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
        case .hero: playerSave.roster.collectionHeroes
        case .companion: playerSave.roster.collectionCompanions
        }
    }

    var body: some View {
        CollectionGridShell(items: combatants) { combatant in
            CollectionCombatantButton(
                combatant: combatant,
                isLocked: !playerSave.roster.isUnlocked(combatant) || !playerSave.contentAccess.allowsCombatant(combatant.id),
                cardWidth: nil,
            ) {
                guard playerSave.contentAccess.allowsCombatant(combatant.id) else {
                    requestOffer(.combatant(combatant.id))
                    return
                }
                selectedCombatant = CombatantDetailContext(
                    kind: kind,
                    combatantID: combatant.id,
                )
            }
            .matchedTransitionSource(id: combatant.id, in: zoomNamespace)
        } emptyView: {
            EmptyView()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .modifier(
            CombatantDetailSheet(
                selection: $selectedCombatant,
                zoomSourceID: { $0.combatantID },
                zoomNamespace: zoomNamespace,
                artworkNames: {
                    CombatantDetailArtwork.rosterArtworkNames(for: $0.combatantID, playerSave: playerSave)
                },
                detailContent: { context in
                    RosterCombatantDetailView(
                        kind: context.kind,
                        combatantID: context.combatantID,
                        hapticsEnabled: options.hapticsEnabled,
                        effectsVolume: options.effectsVolume,
                    )
                },
            ),
        )
    }
}
