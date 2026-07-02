import SwiftUI

struct ChapterHeroHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter
    let completedCount: Int
    let totalCount: Int
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(chapter.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Chapter Progress")
                            .font(.caption.weight(.semibold))

                        Spacer()

                        Text("\(completedCount)/\(totalCount) Cleared")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white.opacity(0.86))

                    ProgressView(value: Double(completedCount), total: Double(totalCount))
                        .tint(chapter.theme.secondaryTint)
                        .progressViewStyle(.linear)
                }
                .frame(maxWidth: 360)
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, metadataBottomPadding)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }

    private var metadataBottomPadding: CGFloat {
        min(max(height * 0.40, 144), 184)
    }
}
