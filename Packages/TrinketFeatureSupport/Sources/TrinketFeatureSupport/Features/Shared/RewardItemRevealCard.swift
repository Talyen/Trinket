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

    private var astralShineKeywords: [Keyword]? {
        guard item.rarity == .astral else { return nil }
        return item.keywords.isEmpty ? Array(item.baseType.keywordAffinities) : Array(item.keywords)
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            ItemArtwork(item: item)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .frame(height: artworkHeight)
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()
                .colorShineBorder(
                    colors: item.rarity == .unique ? UniqueShine.borderColors : nil,
                    cornerRadius: TrinketDesign.Corners.card,
                    lineWidth: 2
                )
                .keywordShineBorder(
                    keywords: astralShineKeywords,
                    cornerRadius: TrinketDesign.Corners.card,
                    lineWidth: 2
                )

            VStack(spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                TrinketRarityLabel(rarity: item.rarity)

                Text(balanced: item.displayName)
                    .trinketTypography(.sectionDisplay)
                    .uniqueShine(if: item.rarity == .unique)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
