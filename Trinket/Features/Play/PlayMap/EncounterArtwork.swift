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

    static func reference(
        for stage: Stage,
        resolvedMysteryEvent: MysteryEvent?,
        worldSeed: UInt64,
    ) -> (any PreparedArtworkReference)? {
        if let art = stage.encounterCombatantArtReference(worldSeed: worldSeed) {
            return art
        }
        if let event = resolvedMysteryEvent {
            if event.isRecruit {
                return GameContent.recruitEncounterArtReference(for: event)
            }
            return MysteryEventArtwork.preparedReference(event: event, chapterID: stage.chapterID)
        }
        if case .recruit = stage.encounter {
            return stage.encounterArtReference
        }
        if let event = stage.mysteryEvent, !event.isRecruit {
            return MysteryEventArtwork.preparedReference(event: event, chapterID: stage.chapterID)
        }
        return stage.encounterArtReference
    }

    var body: some View {
        ZStack {
            if let art = Self.reference(
                for: stage,
                resolvedMysteryEvent: resolvedMysteryEvent,
                worldSeed: worldSeed,
            ) {
                MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
            } else {
                MapTilePlaceholder(
                    tint: stage.encounter.mapTint,
                    icon: GameIcon(id: stage.encounter.iconID),
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
