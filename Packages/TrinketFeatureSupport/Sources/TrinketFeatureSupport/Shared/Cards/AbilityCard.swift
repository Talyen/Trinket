import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityChoiceCard: View {
    let ability: Ability
    var lockLabel: String?
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var isSelected = false

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize =
        TrinketDesign.Metrics.cardPlaceholderIconPointSize

    private var isLocked: Bool {
        lockLabel != nil
    }

    var body: some View {
        ProductCardShell(
            isLocked: isLocked,
            lockedText: lockLabel,
            isSelected: isSelected,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
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

                    Text(ability.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        )
    }
}
