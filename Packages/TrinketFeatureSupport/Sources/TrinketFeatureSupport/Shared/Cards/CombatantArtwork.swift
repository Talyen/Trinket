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
                PreparedArtworkImage(
                    artReference,
                    displaySize: variant == .card ? .compact : .full,
                )
                .modifier(ArtFillModifier(alignment: variant == .hero ? .top : .center))
                .decorativePreparedArtwork()

            } else {
                placeholderArt
            }
        }
        .modifier(BattleFrameModifier(expandsToFrame: variant == .battle))
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

private struct ArtFillModifier: ViewModifier {
    let alignment: Alignment

    func body(content: Content) -> some View {
        Color.clear
            .overlay(alignment: alignment) {
                content.scaledToFill()
            }
            .clipped()
    }
}

private struct BattleFrameModifier: ViewModifier {
    let expandsToFrame: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: expandsToFrame ? .infinity : nil, maxHeight: expandsToFrame ? .infinity : nil)
            .clipped()
    }
}
