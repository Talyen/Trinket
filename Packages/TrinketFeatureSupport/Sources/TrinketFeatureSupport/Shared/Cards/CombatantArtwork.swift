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
                Image.preparedAsset(
                    artReference,
                    displaySize: variant == .card ? .compact : .full
                )
                .resizable()
                .interpolation(interpolation)
                .modifier(ArtFillModifier(variant: variant))
                .decorativePreparedArtwork()

            } else {
                placeholderArt
            }
        }
        .modifier(BattleFrameModifier(variant: variant))
    }

    private var interpolation: Image.Interpolation {
        variant == .card ? .low : .medium
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
    let variant: CombatantArtwork.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .battle:
            // Keep layout size = proposed frame. `scaledToFill()` alone lets square
            // art expand a 4:3 enemy pane taller than its clip, hiding bottom chrome.
            Color.clear
                .overlay {
                    content.scaledToFill()
                }
                .clipped()
        case .card, .hero:
            content.aspectRatio(contentMode: .fill)
        }
    }
}

private struct BattleFrameModifier: ViewModifier {
    let variant: CombatantArtwork.Variant

    func body(content: Content) -> some View {
        if variant == .battle {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            content.clipped()
        }
    }
}
