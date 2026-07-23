import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CombatantCard: View {
    let combatant: Combatant
    var isLocked: Bool = false
    var showsName: Bool = true
    var isSelected = false

    var body: some View {
        ProductCardShell(
            isLocked: isLocked,
            lockedText: "Locked",
            isSelected: isSelected,
            showsLabel: showsName,
            art: {
                CombatantArtwork(combatant: combatant, variant: .card)
            },
            label: {
                Text(combatant.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        )
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
        .trinketQuietTapButtonStyle()
        .allowsHitTesting(!isLocked)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.collectionCard(name: combatant.name))
    }
}
