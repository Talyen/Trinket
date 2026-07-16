import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CombatantCard: View {
    let combatant: Combatant
    var isLocked: Bool = false
    var showsName: Bool = true
    var artworkBlend: ArtworkBlend = .none

    var body: some View {
        VStack(spacing: TrinketDesign.Metrics.smallSpacing) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .trinketArtworkBlend(artworkBlend)
                        .clipShape(TrinketDesign.cardShape)
                }
                .trinketLockedCardEffect(isLocked: isLocked, text: "Locked")
                .trinketCardSurface()

            if showsName {
                Text(combatant.name)
                    .trinketTypography(.cardLabel)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
                    .trinketCardLabelSpace()
            }
        }
    }
}

struct CollectionCombatantButton: View {
    let combatant: Combatant
    let isLocked: Bool
    var cardWidth: CGFloat? = 130
    var showsName: Bool = true
    var artworkBlend: ArtworkBlend = .perimeter(into: .surface)
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let cardWidth {
                    CombatantCard(
                        combatant: combatant,
                        isLocked: isLocked,
                        showsName: showsName,
                        artworkBlend: artworkBlend
                    )
                    .frame(width: cardWidth)
                } else {
                    CombatantCard(
                        combatant: combatant,
                        isLocked: isLocked,
                        showsName: showsName,
                        artworkBlend: artworkBlend
                    )
                }
            }
        }
        .trinketQuietTapButtonStyle()
        .allowsHitTesting(!isLocked)
        .accessibilityIdentifier(AccessibilityID.CombatantDetail.collectionCard(name: combatant.name))
    }
}
