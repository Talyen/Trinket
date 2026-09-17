import SwiftUI

public struct TrinketCompactResourceChip<Artwork: View>: View {
    private let value: String
    private let tint: Color
    private let animationTrigger: Int
    private let artwork: Artwork

    public init(amount: Int, tint: Color, animationTrigger: Int = 0, @ViewBuilder artwork: () -> Artwork) {
        self.init(
            value: TrinketWalletFormatting.displayString(for: amount),
            tint: tint,
            animationTrigger: animationTrigger,
            artwork: artwork,
        )
    }

    public init(value: String, tint: Color, animationTrigger: Int = 0, @ViewBuilder artwork: () -> Artwork) {
        self.value = value
        self.tint = tint
        self.animationTrigger = animationTrigger
        self.artwork = artwork()
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            artwork
                .frame(width: TrinketDesign.Layout.compactResourceArtworkSize, height: TrinketDesign.Layout.compactResourceArtworkSize)
                .trinketWalletIncreaseBump(trigger: animationTrigger)

            Text(value).monospacedDigit().fixedSize().contentTransition(.numericText())
        }
        .trinketTypography(.button)
        .foregroundStyle(tint)
        .trinketGlassChip(.emphasis)
        .animation(TrinketMotion.Interaction.stateChange, value: value)
    }
}
