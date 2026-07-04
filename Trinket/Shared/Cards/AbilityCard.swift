import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityChoiceCard: View {
    let ability: Ability
    var lockLabel: String?
    var showsName: Bool = true
    var reservesLabelSpace: Bool = true

    private var isLocked: Bool {
        lockLabel != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    if let artRef = ability.artReference {
                        Image(artRef.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(TrinketDesign.cardShape)
                            .accessibilityLabel(artRef.accessibilityLabel)
                    } else {
                        ZStack {
                            TrinketDesign.cardShape
                                .fill(TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18))
                            Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .saturation(isLocked ? 0.15 : 1)
                .opacity(isLocked ? 0.65 : 1)
                .overlay {
                    if let lockLabel {
                        TrinketDesign.cardShape
                            .fill(.black.opacity(0.35))
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.title3.weight(.semibold))
                            Text(lockLabel)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 8)
                        }
                        .foregroundStyle(.white)
                    }
                }
                .trinketCardSurface()

            if showsName {
                Text(ability.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .trinketCardLabelSpace(reservesLabelSpace)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let lockLabel {
            return "\(ability.name), \(lockLabel)"
        }
        return "\(ability.name) card"
    }
}
