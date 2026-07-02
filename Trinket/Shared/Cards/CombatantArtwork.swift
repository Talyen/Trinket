import SwiftUI

struct CombatantArtwork: View {
    enum Variant {
        case card
        case hero
        case battle
    }

    let combatant: Combatant
    var variant: Variant = .hero

    var body: some View {
        Group {
            if let artReference = combatant.artReference {
                Image(imageName(for: artReference))
                    .resizable()
                    .interpolation(interpolation)
                    .modifier(ArtFillModifier(variant: variant))
                    .accessibilityLabel(artReference.accessibilityLabel)
            } else {
                placeholderArt
                    .accessibilityLabel("\(combatant.name) placeholder art")
            }
        }
        .modifier(BattleFrameModifier(variant: variant))
    }

    private func imageName(for artReference: CombatantArtReference) -> String {
        switch variant {
        case .card:
            return artReference.thumbnailImageName ?? artReference.imageName
        case .hero, .battle:
            return artReference.imageName
        }
    }

    private var interpolation: Image.Interpolation {
        variant == .card ? .low : .medium
    }

    private var placeholderArt: some View {
        let style: TrinketDesign.CardPlaceholderStyle
        switch combatant.role {
        case .hero: style = .hero
        case .pet: style = .pet
        case .enemy: style = .enemy
        }
        return ZStack {
            style.color.opacity(0.18)

            Image(systemName: style.symbolName)
                .font(.system(size: placeholderIconSize, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }

    private var placeholderIconSize: CGFloat {
        switch variant {
        case .card, .hero:
            return 38
        case .battle:
            return 48
        }
    }
}

private struct ArtFillModifier: ViewModifier {
    let variant: CombatantArtwork.Variant

    func body(content: Content) -> some View {
        switch variant {
        case .battle:
            content.scaledToFill()
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
