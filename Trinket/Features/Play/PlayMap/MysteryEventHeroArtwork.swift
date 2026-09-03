import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysteryEventHeroArtwork: View {
    let event: MysteryEvent
    let chapterID: String
    var prefersThumbnail = false

    var body: some View {
        if let artID = event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            Image.preparedAsset(
                art,
                displaySize: prefersThumbnail ? .compact : .full,
            )
            .resizable()
            .scaledToFill()
            .decorativePreparedArtwork()
        } else if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            Image.preparedAsset(art, displaySize: prefersThumbnail ? .compact : .full)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else if let art = ArtCatalog.backgroundArtByID[chapterID] {
            Image.preparedAsset(art, displaySize: prefersThumbnail ? .compact : .full)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            TrinketDesign.Colors.encounterEvent
        }
    }
}
