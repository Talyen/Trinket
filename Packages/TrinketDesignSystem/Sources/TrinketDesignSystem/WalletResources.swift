import SwiftUI

public struct TrinketWalletGrid<Content: View>: View {
    private let columnCount: Int
    private let hugsContent: Bool
    private let content: Content

    public init(
        columnCount: Int = 4,
        hugsContent: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.columnCount = max(1, columnCount)
        self.hugsContent = hugsContent
        self.content = content()
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: TrinketDesign.Metrics.smallSpacing),
            count: columnCount
        )
    }

    public var body: some View {
        layout
            .frame(maxWidth: hugsContent ? .infinity : nil)
            .padding(TrinketDesign.Metrics.denseSpacing)
            .trinketMaterial(.homesteadFooter)
    }

    @ViewBuilder
    private var layout: some View {
        if hugsContent {
            huggingLayout
        } else {
            LazyVGrid(columns: columns, spacing: TrinketDesign.Metrics.denseSpacing) {
                content
            }
        }
    }

    @ViewBuilder
    private var huggingLayout: some View {
        if columnCount == 1 {
            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.denseSpacing) {
                content
            }
        } else {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                content
            }
        }
    }
}

public struct TrinketWalletResourcePill<Artwork: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let title: String
    private let amount: Int
    private let showsIncreasePrefix: Bool
    private let fillsAvailableWidth: Bool
    private let increaseAnimationDelay: TimeInterval
    private let artwork: Artwork
    @State private var increaseAnimationTrigger = 0

    private var displayedAmount: String {
        let value = amount >= 100000
            ? amount.formatted(.number.notation(.compactName))
            : amount.formatted()
        return showsIncreasePrefix ? "+\(value)" : value
    }

    public init(
        title: String,
        amount: Int,
        showsIncreasePrefix: Bool = false,
        fillsAvailableWidth: Bool = true,
        increaseAnimationDelay: TimeInterval = 0,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.amount = amount
        self.showsIncreasePrefix = showsIncreasePrefix
        self.fillsAvailableWidth = fillsAvailableWidth
        self.increaseAnimationDelay = increaseAnimationDelay
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            artwork
                .frame(
                    width: TrinketDesign.Metrics.walletResourceArtworkSize,
                    height: TrinketDesign.Metrics.walletResourceArtworkSize
                )

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.tightSpacing) {
                Text(title)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Text(displayedAmount)
                    .trinketTypography(.statValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
                    .accessibilityLabel(showsIncreasePrefix ? "Plus \(amount)" : "\(amount)")
            }
        }
        .frame(
            maxWidth: fillsAvailableWidth ? .infinity : nil,
            minHeight: TrinketDesign.Metrics.walletResourceRowMinHeight,
            alignment: .leading
        )
        .animation(TrinketMotion.Homestead.tierCompletion, value: amount)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: increaseAnimationTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            LinearKeyframe(1, duration: increaseAnimationDelay)
            CubicKeyframe(
                TrinketMotion.Interaction.walletIncreaseScale,
                duration: 0.08
            )
            SpringKeyframe(1, duration: 0.18, spring: .smooth)
        }
        .onChange(of: amount) { oldAmount, newAmount in
            guard newAmount > oldAmount, !reduceMotion else { return }
            increaseAnimationTrigger &+= 1
        }
    }
}
