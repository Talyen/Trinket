import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ItemHeroHeader: View {
    let item: InventoryItem
    let baseHeight: CGFloat
    let overscroll: CGFloat

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading,
            artworkBlend: .bottom(into: .canvas)
        ) {
            itemArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            titleBlock
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var itemArtwork: some View {
        ItemArtwork(item: item)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.rarity.label.uppercased())
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text(item.displayName)
                .trinketTypography(.screenDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}
