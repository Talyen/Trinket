import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

/// Shared combatant-detail sheet: artwork acquisition before presentation,
/// zoom transition when the tap site participates in one, frame-pacing
/// signposts when the flow measures them.
///
/// Two families share this chrome with different resolvers and content:
/// roster-backed sheets (Collection, Mystery) resolve through the save, while
/// snapshot sheets (battle overlay, onboarding) render a fixed detail value.
/// Onboarding intentionally resolves with empty equipment/inventory: starter
/// candidates have no roster progression yet, so the roster resolver does not
/// apply there.
@MainActor
struct CombatantDetailSheet<Selection: Hashable & Identifiable, DetailContent: View>: ViewModifier {
    @Binding var selection: Selection?
    /// Zoom source ID for the sheet transition; nil skips the zoom.
    var zoomSourceID: ((Selection) -> String)?
    var zoomNamespace: Namespace.ID?
    /// Frame-pacing signpost detail; nil disables signposts for this sheet.
    var signpostDetail: ((Selection) -> String)?
    let artworkNames: (Selection) -> [String]
    @ViewBuilder let detailContent: (Selection) -> DetailContent

    func body(content: Content) -> some View {
        content.preparedArtworkSheet(item: $selection, artworkNames: artworkNames) { selection in
            NavigationStack {
                detailContent(selection)
            }
            .modifier(CombatantDetailZoom(
                sourceID: zoomSourceID?(selection),
                namespace: zoomNamespace,
            ))
            .trinketDetailSheet()
            .modifier(CombatantDetailSignposts(detail: signpostDetail?(selection)))
        }
    }
}

/// Roster-backed artwork resolver shared by Collection and Mystery sheets.
@MainActor
enum CombatantDetailArtwork {
    static func rosterArtworkNames(for combatantID: String, playerSave: PlayerSaveStore) -> [String] {
        guard let base = GameContent.combatant(matching: combatantID) else { return [] }
        let combatant = playerSave.roster.configuredCombatant(base)
        return CombatantDetailPane.artworkNames(
            combatant: combatant,
            loadout: playerSave.roster.loadout(for: combatant),
            equipmentLoadout: playerSave.roster.equipmentLoadout(for: combatant),
            inventoryItems: playerSave.inventory.items,
        )
    }
}

private struct CombatantDetailZoom: ViewModifier {
    let sourceID: String?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let sourceID, let namespace {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

private struct CombatantDetailSignposts: ViewModifier {
    let detail: String?

    func body(content: Content) -> some View {
        if let detail {
            content
                .appFramePacingSignpost(
                    AppFramePacingSignposts.Name.sheetPresent,
                    isActive: true,
                )
                .onAppear {
                    AppFramePacingSignposts.event(
                        AppFramePacingSignposts.Name.sheetPresent,
                        detail: detail,
                    )
                }
        } else {
            content
        }
    }
}
