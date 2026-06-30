import SwiftUI

struct CombatantCard: View {
    let combatant: Combatant
    var isLocked: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                        .saturation(isLocked ? 0.15 : 1)
                        .opacity(isLocked ? 0.65 : 1)
                }
                .overlay {
                    if isLocked {
                        TrinketDesign.cardShape
                            .fill(.black.opacity(0.35))
                        VStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.title3.weight(.semibold))
                            Text("Locked")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .trinketCardSurface()

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isLocked ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        }
        .accessibilityElement(children: .combine)
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let cardWidth {
                    CombatantCard(combatant: combatant, isLocked: isLocked)
                        .frame(width: cardWidth)
                } else {
                    CombatantCard(combatant: combatant, isLocked: isLocked)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityIdentifier("\(combatant.name) collection card")
    }
}
