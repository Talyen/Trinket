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
        ItemCard(
            item: item,
            showsAffixCount: false,
            presentation: .reveal
        ) {
            ItemArtwork(item: item)
                .frame(height: artworkHeight)
        }
    }
}
