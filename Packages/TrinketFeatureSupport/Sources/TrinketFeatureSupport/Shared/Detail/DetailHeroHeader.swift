import SwiftUI
import TrinketDesignSystem

public struct DetailHeroHeader<Art: View, Footer: View>: View {
    let eyebrow: String?
    let title: String
    var titleShine: Shine
    var titleAccessibilityIdentifier: String?
    let baseHeight: CGFloat
    var horizontalPadding: CGFloat
    var bottomPadding: CGFloat
    var singleLineTitle = false
    @ViewBuilder let art: () -> Art
    @ViewBuilder let footer: () -> Footer

    public init(
        eyebrow: String? = nil,
        title: String,
        titleShine: Shine = .none,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        singleLineTitle: Bool = false,
        @ViewBuilder art: @escaping () -> Art,
        @ViewBuilder footer: @escaping () -> Footer,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.singleLineTitle = singleLineTitle
        self.art = art
        self.footer = footer
    }

    public var body: some View {
        Color.clear
            .frame(height: baseHeight)
            .overlay {
                GeometryReader { geometry in
                    art()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .backgroundExtensionEffect()
                .allowsHitTesting(false)
                .clipped()
                .trinketArtworkBlend(.bottom(into: .canvas))
                .visualEffect { content, proxy in
                    let overscroll = max(proxy.frame(in: .scrollView(axis: .vertical)).minY, 0)
                    let stretch = baseHeight > 0 ? (baseHeight + overscroll) / baseHeight : 1
                    return content
                        .scaleEffect(stretch, anchor: .top)
                        .offset(y: -overscroll)
                }
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

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
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
        let text = Group {
            if singleLineTitle {
                Text(title)
                    .trinketSingleLineFittedText()
            } else {
                Text(balanced: title)
                    .trinketFittedText()
            }
        }
        .trinketTypography(.screenDisplay)
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
        title: String,
        titleShine: Shine = .none,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        singleLineTitle: Bool = false,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.singleLineTitle = singleLineTitle
        self.art = art
        footer = { EmptyView() }
    }
}
