import SwiftUI
import TrinketDesignSystem

/// Shared full-bleed detail hero: art, on-art eyebrow/title, optional footer.
struct DetailHeroHeader<Art: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let baseHeight: CGFloat
    let overscroll: CGFloat
    @ViewBuilder let art: () -> Art
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading,
            artworkBlend: .bottom(into: .canvas)
        ) {
            art()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            VStack(alignment: .leading) {
                titleBlock
                footer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            Text(eyebrow)
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text(title)
                .trinketTypography(.screenDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}

extension DetailHeroHeader where Footer == EmptyView {
    init(
        eyebrow: String,
        title: String,
        baseHeight: CGFloat,
        overscroll: CGFloat,
        @ViewBuilder art: @escaping () -> Art
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.baseHeight = baseHeight
        self.overscroll = overscroll
        self.art = art
        footer = { EmptyView() }
    }
}
