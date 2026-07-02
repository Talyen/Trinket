import SwiftUI

struct ChapterHeroHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                TrinketDesign.Colors.appBackground

                if !reduceTransparency,
                   let bgImageName = ArtCatalog.backgroundArtByID[chapter.id]?.imageName {
                    Image(bgImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .accessibilityHidden(true)
                }

                LinearGradient(
                    colors: [
                        .black.opacity(0.03),
                        .black.opacity(0.08),
                        .black.opacity(0.56)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(chapter.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .accessibilityIdentifier(AccessibilityID.Play.chapterHeader(number: chapter.number))
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }
}
