import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct AbilityChoiceCard: View {
    let ability: Ability
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var isSelected = false
    var shineKeywords: [Keyword]?
    var shineLineWidth: CGFloat = 2

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize =
        TrinketDesign.Metrics.cardPlaceholderIconPointSize

    var body: some View {
        ProductCardShell(
            isSelected: isSelected,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shineKeywords: shineKeywords,
            shineLineWidth: shineLineWidth,
            art: {
                if let artRef = ability.artReference {
                    Image.preparedAsset(artRef, displaySize: .compact)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .decorativePreparedArtwork()
                } else {
                    ZStack {
                        TrinketDesign.cardShape
                            .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                        Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                            .font(.system(size: placeholderIconSize, weight: .semibold))
                            .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                    }
                }
            },
            label: {
                VStack(spacing: TrinketDesign.Metrics.tightSpacing) {
                    Text(ability.tier.rawValue.uppercased())
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(balanced: ability.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        )
    }
}
