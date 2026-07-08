import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem

/// Bottom-up wipe from combatant art into skill art as the action interval charges.
struct SkillChargeArtwork: View {
    let combatant: Combatant
    let skill: Ability
    let progress: Double
    let reduceMotion: Bool

    private var clampedProgress: CGFloat {
        CGFloat(min(1, max(0, progress)))
    }

    private var seamStyle: Keyword.VisualStyle {
        skill.logDamageKeyword.visualStyle
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CombatantArtwork(combatant: combatant, variant: .battle)

                if clampedProgress > 0 {
                    skillArtLayer
                        .mask {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .frame(height: geometry.size.height * clampedProgress)
                            }
                        }
                        .accessibilityHidden(true)

                    if clampedProgress < 1 {
                        seamDivider(in: geometry.size)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .linear(duration: 0.12), value: clampedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(AccessibilityID.Battle.skillCharge(combatantName: combatant.name))
    }

    private var skillArtLayer: some View {
        Group {
            if let artRef = skill.artReference {
                Image(artRef.imageName)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                skillPlaceholder
            }
        }
    }

    private var skillPlaceholder: some View {
        let style = TrinketDesign.CardPlaceholderStyle.ability
        return ZStack {
            style.color.opacity(0.22)
            Image(systemName: style.symbolName)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(style.color)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func seamDivider(in size: CGSize) -> some View {
        let y = size.height * (1 - clampedProgress)
        return Capsule()
            .fill(seamStyle.color)
            .frame(width: size.width, height: 2)
            .shadow(color: seamStyle.glowColor, radius: 6, y: 0)
            .overlay {
                Capsule()
                    .stroke(seamStyle.borderColor, lineWidth: 0.5)
            }
            .position(x: size.width / 2, y: y)
            .allowsHitTesting(false)
    }

    private var accessibilityLabel: String {
        if clampedProgress >= 1 {
            return "\(combatant.name), \(skill.name) ready"
        }
        if clampedProgress > 0 {
            return "\(combatant.name), charging \(skill.name)"
        }
        return "\(combatant.name) card"
    }
}
