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

            VStack(alignment: .leading, spacing: 12) {
                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text(chapter.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                progressPanel
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Chapter Progress")
                    .font(.caption.weight(.semibold))

                Spacer()

                Text("\(completedCount)/\(totalCount) Cleared")
                    .font(.caption.weight(.medium).monospacedDigit())
            }
            .foregroundStyle(.white.opacity(0.9))

            ProgressView(value: Double(completedCount), total: Double(totalCount))
                .tint(chapter.theme.secondaryTint)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 360)
        .background(progressPanelBackground)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(.white.opacity(reduceTransparency ? 0.18 : 0.12), lineWidth: 1)
        }
        .progressGlassEffect(isEnabled: !reduceTransparency)
        .accessibilityElement(children: .combine)
    }

    private var progressPanelBackground: some ShapeStyle {
        reduceTransparency ? AnyShapeStyle(Color.black.opacity(0.58)) : AnyShapeStyle(.thinMaterial)
    }
}

private extension View {
    @ViewBuilder
    func progressGlassEffect(isEnabled: Bool) -> some View {
        if isEnabled {
            glassEffect(.regular)
        } else {
            self
        }
    }
}
