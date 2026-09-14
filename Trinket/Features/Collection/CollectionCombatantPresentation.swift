import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

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
