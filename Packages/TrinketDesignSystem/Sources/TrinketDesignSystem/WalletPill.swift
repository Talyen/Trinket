import SwiftUI

public struct TrinketWalletResourcePill<Artwork: View>: View {
    private let title: String
    private let amount: Int
    private var formattedValue: String?
    private var valueColor: Color = .primary
    private let showsIncreasePrefix: Bool
    private let increaseAnimationDelay: TimeInterval
    private let keepsArtworkStationary: Bool
    private let artwork: Artwork
    @Environment(\.controlSize) private var controlSize
    @State private var increaseAnimationTrigger = 0

    private var displayedAmount: String {
        formattedValue ?? TrinketWalletFormatting.displayString(for: amount, showsIncreasePrefix: showsIncreasePrefix)
    }

    public init(
        title: String,
        amount: Int,
        showsIncreasePrefix: Bool = false,
        increaseAnimationDelay: TimeInterval = 0,
        keepsArtworkStationary: Bool = false,
        @ViewBuilder artwork: () -> Artwork,
    ) {
        self.title = title
        self.amount = amount
        self.showsIncreasePrefix = showsIncreasePrefix
        self.increaseAnimationDelay = increaseAnimationDelay
        self.keepsArtworkStationary = keepsArtworkStationary
        self.artwork = artwork()
    }

    /// Formatted-value variant for production rates and comparisons.
    /// Unlike the `amount:` init, this variant does not animate amount changes.
    public init(title: String, value: String, valueColor: Color = .primary, @ViewBuilder artwork: () -> Artwork) {
        self.init(title: title, amount: 0, artwork: artwork)
        formattedValue = value
        self.valueColor = valueColor
    }

    private var animatesAmountChanges: Bool {
        formattedValue == nil
    }

    private var usesLargeContent: Bool {
        controlSize == .large || controlSize == .extraLarge
    }

    private var artworkSize: CGFloat {
        TrinketDesign.Layout.walletResourceArtworkSize * (usesLargeContent ? 4.0 / 3.0 : 1)
    }

    private var titleLabel: some View {
        Text(title).trinketTypography(usesLargeContent ? .body : .caption)
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .trinketFittedText()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            artwork.frame(width: artworkSize, height: artworkSize)

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                titleLabel

                Text(displayedAmount).trinketTypography(.statValue).foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .contentTransition(.numericText())
                    .trinketWalletIncreaseBump(
                        trigger: increaseAnimationTrigger,
                        delay: increaseAnimationDelay,
                        enabled: keepsArtworkStationary,
                    )
            }
            .animation(animatesAmountChanges ? TrinketMotion.Interaction.walletIncrease : nil, value: amount)
        }
        .frame(minHeight: max(TrinketDesign.Layout.walletResourceRowMinHeight, artworkSize), alignment: .leading)
        .trinketWalletIncreaseBump(
            trigger: increaseAnimationTrigger,
            delay: increaseAnimationDelay,
            enabled: !keepsArtworkStationary,
        )
        .onChange(of: amount) { oldAmount, newAmount in
            guard animatesAmountChanges, newAmount > oldAmount else { return }
            increaseAnimationTrigger &+= 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(displayedAmount)
    }
}
