import SwiftUI
import TrinketCore
import TrinketDesignSystem

public struct DetailHeroHeader<Art: View, Footer: View>: View {
    let eyebrow: String?
    let title: String
    var titleKeywords: Set<Keyword>
    var titleShineColors: [Color]?
    var titleAccessibilityIdentifier: String?
    let baseHeight: CGFloat
    var horizontalPadding: CGFloat
    var bottomPadding: CGFloat
    @ViewBuilder let art: () -> Art
    @ViewBuilder let footer: () -> Footer

    public init(
        eyebrow: String? = nil,
        title: String,
        titleKeywords: Set<Keyword> = [],
        titleShineColors: [Color]? = nil,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder footer: @escaping () -> Footer,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleKeywords = titleKeywords
        self.titleShineColors = titleShineColors
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.art = art
        self.footer = footer
    }

    public var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            alignment: .topLeading,
            artworkBlend: .bottom(into: .canvas),
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
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
            if let eyebrow {
                Text(balanced: eyebrow)
                    .trinketTypography(.eyebrow)
                    .trinketOnArtText(.eyebrow)
                    .trinketFittedText()
            }

            titleText
        }
    }

    @ViewBuilder
    private var titleText: some View {
        let base = Text(balanced: title)
            .trinketTypography(.screenDisplay)
            .trinketOnArtText(.title)
            .trinketFittedText()
        let label = Group {
            if let titleShineColors, !titleShineColors.isEmpty {
                base.colorShine(titleShineColors)
            } else {
                base.keywordShine(titleKeywords)
            }
        }

        if let titleAccessibilityIdentifier {
            label.accessibilityIdentifier(titleAccessibilityIdentifier)
        } else {
            label
        }
    }
}

public extension DetailHeroHeader where Footer == EmptyView {
    init(
        eyebrow: String? = nil,
        title: String,
        titleKeywords: Set<Keyword> = [],
        titleShineColors: [Color]? = nil,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleKeywords = titleKeywords
        self.titleShineColors = titleShineColors
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.art = art
        footer = { EmptyView() }
    }
}
