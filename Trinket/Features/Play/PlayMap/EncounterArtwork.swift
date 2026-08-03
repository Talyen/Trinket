import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct EncounterArtwork: View {
    let stage: Stage
    /// Seeded/pinned non-recruit mystery for unpinned journey stages.
    var resolvedMysteryEvent: MysteryEvent?

    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 42

    private var nonRecruitMysteryEvent: MysteryEvent? {
        if let resolvedMysteryEvent, !resolvedMysteryEvent.isRecruit {
            return resolvedMysteryEvent
        }
        guard let event = stage.mysteryEvent, !event.isRecruit else { return nil }
        return event
    }

    var body: some View {
        ZStack {
            if let combatantArt = stage.encounterCombatantArtReference {
                Image.preparedAsset(named: combatantArt.thumbnailImageName ?? combatantArt.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()

            } else if let event = nonRecruitMysteryEvent {
                MysteryEventHeroArtwork(event: event, chapterID: stage.chapterID)

            } else if let art = stage.encounterArtReference {
                Image.preparedAsset(named: art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()

            } else {
                stage.encounter.mapTint.opacity(0.14)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
