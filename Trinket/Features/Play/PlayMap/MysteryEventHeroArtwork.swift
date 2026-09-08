import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct MysteryEventHeroArtwork: View {
    let event: MysteryEvent
    let chapterID: String
    var prefersThumbnail = false

    var body: some View {
        if let art = MysteryEventArtwork.preparedReference(event: event, chapterID: chapterID) {
            MapTileArtwork(art: art, prefersThumbnail: prefersThumbnail)
        } else {
            TrinketDesign.Colors.encounterEvent
        }
    }
}

enum MysteryEventArtwork {
    static func preparedReference(
        event: MysteryEvent,
        chapterID: String,
    ) -> (any PreparedArtworkReference)? {
        if let artID = event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            return art
        }
        if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            return art
        }
        if let art = ArtCatalog.backgroundArtByID[chapterID] {
            return art
        }
        return nil
    }

    static func focalContent(
        event: MysteryEvent,
        chapterID: String,
    ) -> (imageName: String, thumbnailName: String?, focalPoint: ArtFocalPoint)? {
        if let artID = event.artID, let art = ArtCatalog.encounterArtByID[artID] {
            return (art.imageName, art.thumbnailImageName, ArtFocalPoint(x: 0.5, y: 0.5))
        }
        if let artID = event.artID, let art = ArtCatalog.backgroundArtByID[artID] {
            return (art.imageName, art.thumbnailImageName, art.focalPoint)
        }
        if let art = ArtCatalog.backgroundArtByID[chapterID] {
            return (art.imageName, art.thumbnailImageName, art.focalPoint)
        }
        return nil
    }
}
