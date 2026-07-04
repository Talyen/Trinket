import SwiftUI
import TrinketContent


struct ChapterArt: View {
    let chapter: Chapter
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            chapter.theme.tint.opacity(0.22)

            if !reduceTransparency,
               let bgImageName = ArtCatalog.backgroundArtByID[chapter.id]?.imageName {
                Image(bgImageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
