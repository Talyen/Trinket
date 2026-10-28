import SwiftUI
import TrinketDesignSystem

public struct DetailHeroHeader<Art: View, Footer: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.detailHeroOverscroll) private var overscroll
    @Environment(\.detailHeroTopInset) private var topInset

    let eyebrow: String?
    let eyebrowIndicators: [DetailChangeIndicator]
    let title: String
    var titleShine: Shine
    var titleAccessibilityIdentifier: String?
    let baseHeight: CGFloat
    var horizontalPadding: CGFloat
    var bottomPadding: CGFloat
    var footerSpacing: CGFloat?
    var singleLineTitle = false
    var titleScale: CGFloat = 1
    var eyebrowScale: CGFloat = 1
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
        footerSpacing: CGFloat? = nil,
        singleLineTitle: Bool = false,
        titleScale: CGFloat = 1,
        eyebrowScale: CGFloat = 1,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() },
    ) {
        self.eyebrow = eyebrow
        self.eyebrowIndicators = eyebrowIndicators
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.footerSpacing = footerSpacing
        self.singleLineTitle = singleLineTitle
        self.titleScale = titleScale
        self.eyebrowScale = eyebrowScale
        self.art = art
        self.footer = footer
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            expandingHeader
        } else {
            standardHeader
        }
    }

    private var standardHeader: some View {
        Color.clear
            .frame(height: baseHeight)
            .overlay {
                extendedArtwork
                    .scaleEffect(baseHeight > 0 ? (baseHeight + overscroll) / baseHeight : 1, anchor: .top)
                    .offset(y: -overscroll)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: footerSpacing) {
                    titleBlock
                    footer()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
            }
    }

    private var expandingHeader: some View {
        VStack(alignment: .leading, spacing: footerSpacing) {
            titleBlock
            footer()
        }
        .padding(.top, topInset)
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, minHeight: baseHeight, alignment: .bottomLeading)
        .background {
            GeometryReader { geometry in
                let height = geometry.size.height
                extendedArtwork
                    .scaleEffect(height > 0 ? (height + overscroll) / height : 1, anchor: .top)
                    .offset(y: -overscroll)
                    .allowsHitTesting(false)
            }
        }
    }

    private var artworkFrame: some View {
        GeometryReader { geometry in
            art()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .trinketBottomArtworkBlend()
        // Rasterize the completed fade before native extension and fractional scroll transforms.
        .drawingGroup()
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
                .trinketTypography(.eyebrow, scale: eyebrowScale)
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
        .trinketTypography(.screenDisplay, scale: titleScale)
        .shineText(titleShine)
        .trinketOnArtText(.title)

        if let titleAccessibilityIdentifier {
            text.accessibilityIdentifier(titleAccessibilityIdentifier)
        } else {
            text
        }
    }
}
