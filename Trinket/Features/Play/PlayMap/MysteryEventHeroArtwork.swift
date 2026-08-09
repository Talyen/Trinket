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
            Image.preparedAsset(
                art,
                displaySize: preferThumbnail ? .compact : .full
            )
            .resizable()
            .scaledToFill()
            .decorativePreparedArtwork()
        } else if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let art = ArtCatalog.backgroundArtByID[chapterID] {
            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            TrinketDesign.Colors.encounterEvent
        }
    }
}
