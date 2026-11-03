import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct RewardItemRevealCard: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let item: InventoryItem

    private var artworkHeight: CGFloat {
        verticalSizeClass == .compact ? 180 : 234
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            ItemCard(
                item: item,
                showsAffixCount: false,
                showsName: false,
            ) {
                ItemArtwork(item: $0)
            }
            .frame(width: artworkHeight * 3.0 / 4.0)

            ItemRevealLabel(item: item)
                .padding(.horizontal, TrinketDesign.Spacing.extraSmall)
                .trinketCardLabelSpace()
        }
        .frame(maxWidth: .infinity)
    }
}
