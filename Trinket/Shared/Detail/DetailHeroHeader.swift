import SwiftUI
import TrinketDesignSystem

/// Shared full-bleed detail hero: art, on-art eyebrow/title, optional footer.
struct DetailHeroHeader<Art: View, Footer: View>: View {
    let eyebrow: String?
    let title: String
    var titleAccessibilityIdentifier: String?
    let baseHeight: CGFloat
    let overscroll: CGFloat
    /// Matches prior `.padding()` on portrait detail heroes.
    var horizontalPadding: CGFloat
    var bottomPadding: CGFloat
    @ViewBuilder let art: () -> Art
    @ViewBuilder let footer: () -> Footer

    init(
        eyebrow: String? = nil,
        title: String,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        overscroll: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Metrics.largeSpacing,
        bottomPadding: CGFloat = TrinketDesign.Metrics.largeSpacing,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.overscroll = overscroll
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.art = art
        self.footer = footer
    }

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
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
            if let eyebrow {
                Text(eyebrow)
                    .trinketTypography(.eyebrow)
                    .trinketOnArtText(.eyebrow)
            }

            titleText
        }
    }

    @ViewBuilder
    private var titleText: some View {
        let label = Text(title)
            .trinketTypography(.screenDisplay)
            .trinketOnArtText(.title)
            .lineLimit(2)
            .minimumScaleFactor(0.75)

        if let titleAccessibilityIdentifier {
            label.accessibilityIdentifier(titleAccessibilityIdentifier)
        } else {
            label
        }
    }
}

extension DetailHeroHeader where Footer == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        overscroll: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Metrics.largeSpacing,
        bottomPadding: CGFloat = TrinketDesign.Metrics.largeSpacing,
        @ViewBuilder art: @escaping () -> Art
    ) {
        self.init(
            eyebrow: eyebrow,
            title: title,
            titleAccessibilityIdentifier: titleAccessibilityIdentifier,
            baseHeight: baseHeight,
            overscroll: overscroll,
            horizontalPadding: horizontalPadding,
            bottomPadding: bottomPadding,
            art: art,
            footer: { EmptyView() }
        )
    }
}
