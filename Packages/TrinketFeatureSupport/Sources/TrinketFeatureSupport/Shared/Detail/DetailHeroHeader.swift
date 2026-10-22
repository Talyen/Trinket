import SwiftUI
import TrinketDesignSystem

public struct DetailHeroHeader<Art: View, Footer: View>: View {
    @Environment(\.detailHeroOverscroll) private var overscroll

    let eyebrow: String?
    let eyebrowIndicators: [DetailChangeIndicator]
    let title: String
    var titleShine: Shine
    var titleAccessibilityIdentifier: String?
    let baseHeight: CGFloat
    var horizontalPadding: CGFloat
    var bottomPadding: CGFloat
    var singleLineTitle = false
    var titleTypography: TypographyRole = .screenDisplay
    var eyebrowTypography: TypographyRole = .eyebrow
    @ViewBuilder let art: () -> Art
    @ViewBuilder let footer: () -> Footer

    public init(
        eyebrow: String? = nil,
        eyebrowIndicators: [DetailChangeIndicator] = [],
        title: String,
        titleShine: Shine = .none,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        singleLineTitle: Bool = false,
        titleTypography: TypographyRole = .screenDisplay,
        eyebrowTypography: TypographyRole = .eyebrow,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder footer: @escaping () -> Footer,
    ) {
        self.eyebrow = eyebrow
        self.eyebrowIndicators = eyebrowIndicators
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.singleLineTitle = singleLineTitle
        self.titleTypography = titleTypography
        self.eyebrowTypography = eyebrowTypography
        self.art = art
        self.footer = footer
    }

    public var body: some View {
        Color.clear
            .frame(height: baseHeight)
            .overlay {
                extendedArtwork
                    .scaleEffect(baseHeight > 0 ? (baseHeight + overscroll) / baseHeight : 1, anchor: .top)
                    .offset(y: -overscroll)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading) {
                    titleBlock
                    footer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
            }
    }

    private var artworkFrame: some View {
        GeometryReader { geometry in
            art()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .trinketBottomArtworkBlend()
    }

    @ViewBuilder
    private var extendedArtwork: some View {
        if #available(iOS 26.0, *) {
            // Extend the cropped, blended artwork; an outer clip would cut off the side-bar background.
            artworkFrame.backgroundExtensionEffect()
        } else {
            artworkFrame
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
            if eyebrow != nil || !eyebrowIndicators.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.extraSmall) {
                    DetailChangeIndicators(indicators: eyebrowIndicators)
                    if let eyebrow {
                        GameLabel(eyebrow, balanced: true)
                            .trinketOnArtText(.eyebrow)
                            .trinketFittedText()
                    }
                }
                .trinketTypography(eyebrowTypography)
            }

            titleText
        }
    }

    @ViewBuilder
    private var titleText: some View {
        let text = Group {
            if singleLineTitle {
                GameLabel(title)
                    .trinketSingleLineFittedText()
            } else {
                GameLabel(title, balanced: true)
                    .trinketFittedText()
            }
        }
        .trinketTypography(titleTypography)
        .shineText(titleShine)
        .trinketOnArtText(.title)

        if let titleAccessibilityIdentifier {
            text.accessibilityIdentifier(titleAccessibilityIdentifier)
        } else {
            text
        }
    }
}

public extension DetailHeroHeader where Footer == EmptyView {
    init(
        eyebrow: String? = nil,
        eyebrowIndicators: [DetailChangeIndicator] = [],
        title: String,
        titleShine: Shine = .none,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        singleLineTitle: Bool = false,
        titleTypography: TypographyRole = .screenDisplay,
        eyebrowTypography: TypographyRole = .eyebrow,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.eyebrow = eyebrow
        self.eyebrowIndicators = eyebrowIndicators
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.singleLineTitle = singleLineTitle
        self.titleTypography = titleTypography
        self.eyebrowTypography = eyebrowTypography
        self.art = art
        footer = { EmptyView() }
    }
}
