import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityHeroHeader: View {
    let ability: Ability
    let baseHeight: CGFloat
    let overscroll: CGFloat

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        OverscrollHeroContainer(
            baseHeight: baseHeight,
            overscroll: overscroll,
            alignment: .topLeading
        ) {
            abilityArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } overlay: {
            ZStack(alignment: .bottomLeading) {
                TrinketHeroScrim.gradient(for: .detailHeader)
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
        .accessibilityLabel("\(ability.name), \(ability.tier.rawValue)")
    }

    @ViewBuilder
    private var abilityArtwork: some View {
        if let artReference = ability.artReference {
            Image(artReference.imageName)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .clipped()
                .accessibilityLabel(artReference.accessibilityLabel)
        } else {
            placeholderArt
                .accessibilityLabel("\(ability.name) placeholder art")
        }
    }

    private var placeholderArt: some View {
        let style = TrinketDesign.CardPlaceholderStyle.ability
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
        VStack(alignment: .leading, spacing: 4) {
            Text(ability.tier.rawValue.uppercased())
                .trinketTypography(.eyebrow)
                .trinketOnArtText(.eyebrow)

            Text(ability.name)
                .trinketTypography(.screenDisplay)
                .trinketOnArtText(.title)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}
