import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadMaterialValue: View {
    let resource: HomesteadResource
    let value: String
    var available: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
            TrinketWalletResourcePill(title: resource.displayName, value: value) {
                HomesteadResourceArtwork(resource: resource)
            }
            if let available {
                Text("Have \(available)")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resource.displayName)
        .accessibilityValue(available.map { "\(value), have \($0)" } ?? value)
    }
}

struct HomesteadBenefitsView: View {
    let tier: HomesteadNodeTier
    let effectsIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Spacing.medium) {
            HomesteadEffectDescription(tier: tier)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(effectsIdentifier)
            if let production = tier.production {
                HomesteadMaterialValue(resource: production.resource, value: "\(production.quantity) per day")
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

struct HomesteadEffectDescription: View {
    let tier: HomesteadNodeTier

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            ForEach(HomesteadEffectLine.lines(for: tier).filter { $0.resource == nil }) { effect in
                Text(attributedEffect(effect))
            }
        }
        .trinketTypography(.body)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func attributedEffect(_ effect: HomesteadEffectLine) -> AttributedString {
        var text = KeywordDescriptionText.attributedText(for: effect.label + " ")
        var value = AttributedString(effect.displayValue)
        value.inlinePresentationIntent = .stronglyEmphasized
        value.foregroundColor = .primary
        text += value
        return text
    }
}

struct HomesteadTierProgress: View {
    let currentTier: Int
    let totalTiers: Int
    var celebrationCount = 0

    var body: some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            ForEach(0 ..< totalTiers, id: \.self) { index in
                Capsule()
                    .fill(index < currentTier ? TrinketDesign.Colors.accent : .clear)
                    .overlay {
                        Capsule().strokeBorder(
                            index < currentTier ? TrinketDesign.Colors.accent : TrinketDesign.Colors.Overlay.paper.opacity(0.45),
                            lineWidth: 1,
                        )
                    }
                    .frame(height: 6)
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: celebrationCount) { content, scale in
                        content.scaleEffect(y: index == currentTier - 1 ? scale : 1)
                    } keyframes: { _ in
                        CubicKeyframe(HomesteadMotion.celebrationPeak, duration: HomesteadMotion.celebrationRise)
                        SpringKeyframe(1, duration: HomesteadMotion.celebrationSettle, spring: .smooth)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building progress")
        .accessibilityValue("\(currentTier) of \(totalTiers) upgrades")
    }
}
