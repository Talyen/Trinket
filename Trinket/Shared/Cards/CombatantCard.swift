import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CombatantCard: View {
    let combatant: Combatant
    var isLocked: Bool = false
    var showsName: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                }
                .trinketLockedCardEffect(isLocked: isLocked, text: "Locked")
                .trinketCardSurface()

            if showsName {
                Text(combatant.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .trinketCardLabelSpace()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isLocked {
            return "\(combatant.name), locked"
        }
        return "\(combatant.name) card"
    }
}

struct CollectionCombatantButton: View {
    let combatant: Combatant
    let isLocked: Bool
    var cardWidth: CGFloat? = 130
    var showsName: Bool = true
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let cardWidth {
                    CombatantCard(
                        combatant: combatant,
                        isLocked: isLocked,
                        showsName: showsName
                    )
                    .frame(width: cardWidth)
                } else {
                    CombatantCard(
                        combatant: combatant,
                        isLocked: isLocked,
                        showsName: showsName
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLocked)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.collectionCard(name: combatant.name))
    }
}
