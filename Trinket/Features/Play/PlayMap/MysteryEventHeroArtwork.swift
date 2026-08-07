import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

/// Hero artwork chain shared by Mystery encounter reading and Active Stage Cards.
struct MysteryEventHeroArtwork: View {
    let event: MysteryEvent
    let chapterID: String
    /// Labyrinth hex seals prefer encounter thumbs; large surfaces keep full art.
    var preferThumbnail = false

    var body: some View {
        if let artID = event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            Image.preparedAsset(named: encounterImageName(art))
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let art = ArtCatalog.backgroundArtByID[chapterID] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            TrinketDesign.Colors.encounterEvent
        }
    }

    private func encounterImageName(_ art: EncounterArtReference) -> String {
        if preferThumbnail {
            art.thumbnailImageName ?? art.imageName
        } else {
            art.imageName
        }
    }
}
