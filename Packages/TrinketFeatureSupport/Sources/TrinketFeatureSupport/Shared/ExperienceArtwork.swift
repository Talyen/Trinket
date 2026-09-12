import SwiftUI
import TrinketContent

public struct ExperienceArtwork: View {
    public init() {}

    public var body: some View {
        if let art = ArtCatalog.resourceArtByID["experience"] {
            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .scaledToFit()
                .decorativePreparedArtwork()
        }
    }
}
