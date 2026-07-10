import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ItemHeroHeader: View {
    let item: InventoryItem
    let baseHeight: CGFloat
    let overscroll: CGFloat

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading
        ) {
            itemArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: HeroHeaderLayout.scrimHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                titleBlock
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.rarity.label)")
    }

    @ViewBuilder
    private var itemArtwork: some View {
        if let artReference = item.artReference {
            Image(artReference.imageName)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .clipped()
                .accessibilityLabel(artReference.accessibilityLabel)
        } else {
            placeholderArt
                .accessibilityLabel("\(item.displayName) placeholder art")
        }
    }

    private var placeholderArt: some View {
        let style = TrinketDesign.CardPlaceholderStyle.item
        return ZStack {
            style.color.opacity(0.18)

            Image(systemName: style.symbolName)
                .font(.system(size: placeholderIconSize, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading) {
            Text(item.displayName)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(item.rarity.label.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }
}
