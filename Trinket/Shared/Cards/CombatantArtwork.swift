import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct CombatantArtwork: View {
    enum Variant {
        case card
        case hero
        case battle
    }

    let combatant: Combatant
    var variant: Variant = .hero

    @ScaledMetric(relativeTo: .title) private var cardHeroIconSize: CGFloat = 38
    @ScaledMetric(relativeTo: .largeTitle) private var battleIconSize: CGFloat = 48

    var body: some View {
        Group {
            if let artReference = combatant.artReference {
                Image.preparedAsset(named: imageName(for: artReference))
                    .resizable()
                    .interpolation(interpolation)
                    .modifier(ArtFillModifier(variant: variant))

            } else {
                placeholderArt
            }
        }
        .modifier(BattleFrameModifier(variant: variant))
    }

    private func imageName(for artReference: CombatantArtReference) -> String {
        switch variant {
        case .card:
            artReference.thumbnailImageName ?? artReference.imageName
        case .hero, .battle:
            artReference.imageName
        }
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
        return ZStack {
            style.color.opacity(0.18)

            Image(systemName: style.symbolName)
                .font(.system(size: placeholderIconSize, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
        }
    }

    private var placeholderIconSize: CGFloat {
        switch variant {
        case .card, .hero:
            cardHeroIconSize
        case .battle:
            battleIconSize
        }
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
