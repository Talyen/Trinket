import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityChoiceCard: View {
    let ability: Ability
    var lockLabel: String?
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true
    var artworkBlend: ArtworkBlend = .none

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    private var isLocked: Bool {
        lockLabel != nil
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let artRef = ability.artReference {
                        Image(artRef.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .trinketArtworkBlend(artworkBlend)
                            .clipShape(TrinketDesign.cardShape)

                    } else {
                        ZStack {
                            TrinketDesign.cardShape
                                .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                            Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                                .font(.system(size: placeholderIconSize, weight: .semibold))
                                .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                        }
                    }
                }
                .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)
                .trinketCardSurface()

            if showsName {
                Text(ability.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
    }
}
