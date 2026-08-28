import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct EncounterArtwork: View {
    let stage: Stage
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

    private var recruitSceneArt: EncounterArtReference? {
        if let event = resolvedMysteryEvent, event.isRecruit {
            return GameContent.recruitEncounterArtReference(for: event)
        }
        guard case .recruit = stage.encounter else { return nil }
        return stage.encounterArtReference
    }

    var body: some View {
        ZStack {
            if let combatantArt = stage.encounterCombatantArtReference(worldSeed: worldSeed) {
                MapTileArtwork(art: combatantArt, prefersThumbnail: prefersThumbnail)
            } else if let art = recruitSceneArt {
                MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
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
