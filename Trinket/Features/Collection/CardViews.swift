import SwiftUI

struct AbilityChoiceCard: View {
    let ability: Ability

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(ability.damageKeyword.visualStyle.color.opacity(0.18))
                }
                .overlay {
                    Image(systemName: ability.damageKeyword.visualStyle.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(ability.damageKeyword.visualStyle.color)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            Text(ability.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ability.name) card")
    }
}

struct EmptyAbilitySlotCard: View {
    let tier: AbilityTier

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    Image(systemName: tier.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            Text("Empty \(tier.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ItemCard: View {
    let item: InventoryItem
    var showsAffixCount: Bool
    var showsName: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    TrinketDesign.cardShape
                        .fill(item.baseType.slot.visualStyle.accentColor.opacity(0.18))
                }
                .overlay {
                    Image(systemName: item.baseType.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(item.baseType.slot.visualStyle.accentColor)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            if showsName {
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName), \(item.baseType.slot.rawValue)")
    }
}

struct EmptyItemSlotCard: View {
    let slot: ItemSlot

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    Image(systemName: slot.symbolName)
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .trinketCardSurface()

            Text("Empty \(slot.rawValue)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Empty \(slot.rawValue) slot")
    }
}

struct CombatantCard: View {
    let combatant: Combatant

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                }
                .trinketCardSurface()

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(minHeight: TrinketDesign.Metrics.cardLabelReservedHeight, alignment: .center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name) card")
    }
}

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
        ZStack {
            TrinketDesign.Colors.cardArtAccent.opacity(0.18)

            Image(systemName: combatant.role.fallbackArtSymbolName)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(TrinketDesign.Colors.cardArtAccent)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
    }
}

extension Combatant.Role {
    var fallbackArtSymbolName: String {
        switch self {
        case .hero:
            return "person.fill"
        case .pet:
            return "pawprint.fill"
        case .enemy:
            return "flame.fill"
        }
    }
}

extension AbilityTier {
    var symbolName: String {
        switch self {
        case .basic:
            return "circle.fill"
        case .skill:
            return "sparkles"
        case .ultimate:
            return "star.fill"
        }
    }

    var cadenceLabel: String {
        switch self {
        case .basic:
            return "Every turn"
        case .skill:
            return "Every 3 turns"
        case .ultimate:
            return "Every 6 turns"
        }
    }
}
