import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct EncounterArtwork: View {
    let stage: Stage
    /// Seeded/pinned non-recruit mystery for unpinned journey stages.
    var resolvedMysteryEvent: MysteryEvent?
    var worldSeed: UInt64 = 0
    var prefersThumbnail = false

    private var nonRecruitMysteryEvent: MysteryEvent? {
        if let resolvedMysteryEvent, !resolvedMysteryEvent.isRecruit {
            return resolvedMysteryEvent
        }
        guard let event = stage.mysteryEvent, !event.isRecruit else { return nil }
        return event
    }

    var body: some View {
        ZStack {
            if let combatantArt = stage.encounterCombatantArtReference(worldSeed: worldSeed) {
                MapTileArtwork(art: combatantArt, prefersThumbnail: prefersThumbnail)
            } else if let event = nonRecruitMysteryEvent {
                MysteryEventHeroArtwork(
                    event: event,
                    chapterID: stage.chapterID,
                    preferThumbnail: prefersThumbnail
                )
            } else if let art = stage.encounterArtReference {
                MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
            } else {
                MapTilePlaceholder(
                    tint: stage.encounter.mapTint,
                    symbolName: stage.encounter.symbolName
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
