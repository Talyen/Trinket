import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityDetailSheetItem: Identifiable {
    let ability: Ability

    var id: String {
        ability.id
    }
}

struct AbilityDetailSheet: View {
    let ability: Ability

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 56

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    artwork
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)

                    Text(ability.name)
                        .font(.title2.weight(.semibold))
                    Text(ability.tier.rawValue)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                    Text(ability.summary)
                        .trinketTypography(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Ability")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var artwork: some View {
        TrinketDesign.cardShape
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                if let artReference = ability.artReference {
                    Image(artReference.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .accessibilityLabel(artReference.accessibilityLabel)
                } else {
                    ZStack {
                        TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18)
                        Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                            .font(.system(size: placeholderIconSize, weight: .semibold))
                            .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                            .accessibilityHidden(true)
                    }
                }
            }
            .trinketCardSurface()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(ability.name) ability art")
    }
}
