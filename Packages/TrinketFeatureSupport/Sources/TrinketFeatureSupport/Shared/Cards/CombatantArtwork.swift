import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct CombatantArtwork: View {
    public enum Variant {
        case card
        case hero
        case battle
    }

    public let combatant: Combatant
    public var variant: Variant = .hero

    public init(combatant: Combatant, variant: Variant = .hero) {
        self.combatant = combatant
        self.variant = variant
    }

    public var body: some View {
        Group {
            if let artReference = combatant.artReference {
                Color.clear
                    .overlay(alignment: variant == .hero ? .top : .center) {
                        PreparedArtworkImage(
                            artReference,
                            displaySize: variant == .card ? .compact : .full,
                        )
                        .scaledToFill()
                    }
                    .decorativePreparedArtwork()
            } else {
                placeholderArt
            }
        }
        .frame(
            maxWidth: variant == .battle ? .infinity : nil,
            maxHeight: variant == .battle ? .infinity : nil,
        )
        .clipped()
    }

    private var placeholderArt: some View {
        let style: TrinketDesign.CardPlaceholderStyle = switch combatant.role {
        case .hero: .hero
        case .companion: .companion
        case .enemy: .enemy
        }
        guard variant == .battle else {
            return PlaceholderArtwork(style)
        }
        return PlaceholderArtwork(style, iconPointSize: 48, relativeTo: .largeTitle)
    }
}
