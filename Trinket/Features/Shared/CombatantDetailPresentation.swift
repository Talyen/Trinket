import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

/// Shared combatant-detail sheet: artwork acquisition before presentation,
/// native sheet motion, and optional frame-pacing signposts.
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
    /// Frame-pacing signpost detail; nil disables signposts for this sheet.
    var signpostDetail: ((Selection) -> String)?
    let artworkNames: (Selection) -> [String]
    @ViewBuilder let detailContent: (Selection) -> DetailContent

    func body(content: Content) -> some View {
        content.preparedArtworkSheet(item: $selection, artworkNames: artworkNames) { selection in
            NavigationStack {
                detailContent(selection)
            }
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
