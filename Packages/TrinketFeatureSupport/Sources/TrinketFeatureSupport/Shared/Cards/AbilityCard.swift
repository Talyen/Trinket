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
                    Image.preparedAsset(artRef, displaySize: .compact)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .decorativePreparedArtwork()
                } else {
                    PlaceholderArtwork(.ability)
                }
            },
            label: {
                VStack(spacing: TrinketDesign.Spacing.tight) {
                    Text(balanced: ability.tier.rawValue.uppercased())
                        .trinketTypography(.eyebrow)
                        .foregroundStyle(.secondary)
                        .trinketFittedText()

                    Text(balanced: ability.name)
                        .trinketTypography(.cardLabel)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .trinketFittedText()
                }
            },
        )
    }
}
