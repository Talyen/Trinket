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
            CollectionCombatantDetailSheet(
                selection: $selectedCombatant,
                zoomNamespace: zoomNamespace,
            ),
        )
    }
}

@MainActor
struct CollectionCombatantDetailSheet: ViewModifier {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave

    @Binding var selection: CombatantDetailContext?
    let zoomNamespace: Namespace.ID
    var issuesSignposts = false

    func body(content: Content) -> some View {
        content.preparedArtworkSheet(item: $selection, artworkNames: artworkNames) { context in
            presentation(context: context)
        }
    }

    private func artworkNames(for selection: CombatantDetailContext) -> [String] {
        guard let base = GameContent.combatant(matching: selection.combatantID) else { return [] }
        let combatant = playerSave.roster.configuredCombatant(base)
        return CombatantDetailPane.artworkNames(
            combatant: combatant,
            loadout: playerSave.roster.loadout(for: combatant),
            equipmentLoadout: playerSave.roster.equipmentLoadout(for: combatant),
            inventoryItems: playerSave.inventory.items,
        )
    }

    private func presentation(context: CombatantDetailContext) -> some View {
        NavigationStack {
            RosterCombatantDetailView(
                kind: context.kind,
                combatantID: context.combatantID,
                hapticsEnabled: options.hapticsEnabled,
                effectsVolume: options.effectsVolume,
            )
        }
        .navigationTransition(.zoom(sourceID: context.combatantID, in: zoomNamespace))
        .trinketDetailSheet()
        .modifier(
            CollectionCombatantSheetSignposts(
                combatantID: context.combatantID,
                isActive: issuesSignposts,
            ),
        )
    }
}

private struct CollectionCombatantSheetSignposts: ViewModifier {
    let combatantID: String
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true,
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: "collectionCombatant=\(combatantID)",
                    )
                }
        } else {
            content
        }
    }
}
