import SwiftUI

struct CombatantArtwork: View {
    enum Variant {
        case card
        case hero
    }

    let combatant: Combatant
    var variant: Variant = .hero

    var body: some View {
        if let artReference = combatant.artReference {
            let imageName = variant == .card
                ? (artReference.thumbnailImageName ?? artReference.imageName)
                : artReference.imageName
            Image(imageName)
                .resizable()
                .interpolation(variant == .card ? .low : .medium)
                .aspectRatio(contentMode: .fill)
                .clipped()
                .accessibilityLabel(artReference.accessibilityLabel)
        } else {
            placeholderArt
                .accessibilityLabel("\(combatant.name) placeholder art")
        }
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
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}
