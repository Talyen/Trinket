import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

struct AbilityChoiceCard: View {
    let ability: Ability
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var isSelected = false
    var shine: Shine = .none
    var shineLineWidth: CGFloat = 2

    var body: some View {
        ProductCardShell(
            isSelected: isSelected,
            showsLabel: showsName,
            reservesLabelSpace: reservesLabelSpace,
            shine: shine,
            shineLineWidth: shineLineWidth,
            art: {
                if let artRef = ability.artReference {
                    PreparedArtworkImage(artRef, displaySize: .compact)
                        .aspectRatio(contentMode: .fill)
                        .decorativePreparedArtwork()
                } else {
                    PlaceholderArtwork(.ability)
                }
            },
            label: {
                VStack(spacing: TrinketDesign.Spacing.tight) {
                    GameLabel(ability.tier.rawValue, balanced: true)
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(.secondary)
                        .trinketFittedText()

                    GameLabel(ability.name, balanced: true)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                }
            },
        )
    }
}
