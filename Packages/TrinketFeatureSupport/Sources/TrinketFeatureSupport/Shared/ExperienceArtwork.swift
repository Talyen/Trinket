import SwiftUI
import TrinketContent

public struct ExperienceArtwork: View {
    public init() {}

    public var body: some View {
        if let art = ArtCatalog.resourceArtByID["experience"] {
            PreparedArtworkImage(art, displaySize: .full)
                .scaledToFit()
                .decorativePreparedArtwork()
        }
    }
}
