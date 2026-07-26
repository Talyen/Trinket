import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct RewardItemRevealCard: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let item: InventoryItem

    private var artworkHeight: CGFloat {
        verticalSizeClass == .compact ? 180 : 234
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ItemArtwork(item: item)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(height: artworkHeight)
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()

            VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                TrinketRarityLabel(rarity: item.rarity)

                Text(item.displayName)
                    .trinketTypography(.sectionDisplay)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
