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
        self.art = art
        self.footer = footer
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            art()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .backgroundExtensionEffect()
                .allowsHitTesting(false)
                .frame(height: baseHeight)
                .clipped()
                .trinketArtworkBlend(.bottom(into: .canvas))
                .visualEffect { content, proxy in
                    let overscroll = max(proxy.frame(in: .scrollView(axis: .vertical)).minY, 0)
                    let stretch = baseHeight > 0 ? (baseHeight + overscroll) / baseHeight : 1
                    return content
                        .scaleEffect(stretch, anchor: .top)
                        .offset(y: -overscroll)
                }

            VStack(alignment: .leading) {
                titleBlock
                footer()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frame(height: baseHeight)
            .clipped()
        }
        .frame(height: baseHeight)
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
        let label = Text(balanced: title)
            .trinketTypography(.screenDisplay)
            .trinketOnArtText(.title)
            .trinketFittedText()
            .shineText(titleShine)

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
        titleShine: Shine = .none,
        titleAccessibilityIdentifier: String? = nil,
        baseHeight: CGFloat,
        horizontalPadding: CGFloat = TrinketDesign.Spacing.large,
        bottomPadding: CGFloat = TrinketDesign.Spacing.large,
        @ViewBuilder art: @escaping () -> Art,
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.titleShine = titleShine
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.baseHeight = baseHeight
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.art = art
        footer = { EmptyView() }
    }
}
