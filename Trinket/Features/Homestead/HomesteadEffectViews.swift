import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct HomesteadMaterialValue: View {
    let resource: HomesteadResource
    let value: String
    var isInsufficient = false

    var body: some View {
        TrinketWalletResourcePill(
            title: resource.displayName,
            value: value,
            valueColor: isInsufficient ? TrinketDesign.Colors.destructive : .primary,
        ) {
            HomesteadResourceArtwork(resource: resource)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resource.displayName)
        .accessibilityValue(isInsufficient ? "\(value), insufficient" : value)
    }
}

struct HomesteadBenefitsView: View {
    let tier: HomesteadNodeTier
    let effectsIdentifier: String
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []
    var highlightsProduction = false

    var body: some View {
        HStack(alignment: .center, spacing: TrinketDesign.Spacing.medium) {
            HomesteadEffectDescription(tier: tier, highlightedEffects: highlightedEffects)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(effectsIdentifier)
            if let production = tier.production {
                HomesteadProductionValue(
                    resource: production.resource,
                    quantity: production.quantity,
                    isHighlighted: highlightsProduction,
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}

private struct HomesteadProductionValue: View {
    let resource: HomesteadResource
    let quantity: Int
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: TrinketDesign.Spacing.small) {
            HomesteadResourceArtwork(resource: resource)
                .frame(width: TrinketDesign.Layout.walletResourceArtworkSize, height: TrinketDesign.Layout.walletResourceArtworkSize)
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                Text(resource.displayName)
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                Text("\(quantity) per day")
                    .trinketTypography(.statValue)
                    .foregroundStyle(isHighlighted ? TrinketDesign.Colors.accent : .primary)
                    .contentTransition(.numericText())
                    .scaleEffect(isHighlighted ? 1.08 : 1, anchor: .leading)
            }
        }
        .frame(minHeight: TrinketDesign.Layout.walletResourceRowMinHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resource.displayName)
        .accessibilityValue("\(quantity) per day")
    }
}

struct HomesteadEffectDescription: View {
    let tier: HomesteadNodeTier
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            ForEach(HomesteadEffectLine.lines(for: tier).filter { $0.resource == nil }) { effect in
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.extraSmall) {
                    Text(KeywordDescriptionText.attributedText(for: effect.label))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(effect.displayValue)
                        .bold()
                        .foregroundStyle(highlightedEffects.contains(effect.id) ? TrinketDesign.Colors.accent : .primary)
                        .contentTransition(.numericText())
                        .scaleEffect(highlightedEffects.contains(effect.id) ? 1.08 : 1, anchor: .leading)
                        .fixedSize()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .trinketTypography(.body)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HomesteadTierProgress: View {
    let currentTier: Int
    let totalTiers: Int
    var celebrationCount = 0

    var body: some View {
        HStack(spacing: TrinketDesign.Spacing.extraSmall) {
            ForEach(0 ..< totalTiers, id: \.self) { index in
                Color.clear
                    .frame(height: 6)
                    .keyframeAnimator(initialValue: HomesteadSegmentMotion(), trigger: celebrationCount) { _, motion in
                        Capsule()
                            .fill(index < currentTier ? TrinketDesign.Colors.accent : .clear)
                            .scaleEffect(x: index == currentTier - 1 ? motion.fill : 1, anchor: .leading)
                            .overlay {
                                Capsule().strokeBorder(
                                    index < currentTier ? TrinketDesign.Colors.accent : TrinketDesign.Colors.Overlay.paper.opacity(0.45),
                                    lineWidth: 1,
                                )
                            }
                            .scaleEffect(
                                x: index == currentTier - 1 ? 1 + (motion.scale - 1) * 0.08 : 1,
                                y: index == currentTier - 1 ? motion.scale : 1,
                            )
                            .shadow(
                                color: TrinketDesign.Colors.accent.opacity(
                                    index == currentTier - 1 ? max(0, Double(motion.scale - 1)) * 0.4 : 0,
                                ),
                                radius: 6,
                            )
                            .frame(height: 6)
                    } keyframes: { _ in
                        KeyframeTrack(\.fill) {
                            LinearKeyframe(0, duration: 0)
                            CubicKeyframe(1, duration: HomesteadMotion.celebrationRise)
                        }
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(HomesteadMotion.celebrationPeak, duration: HomesteadMotion.celebrationRise)
                            SpringKeyframe(1, duration: HomesteadMotion.celebrationSettle, spring: .smooth)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Building progress")
        .accessibilityValue("\(currentTier) of \(totalTiers) upgrades")
    }
}

private struct HomesteadSegmentMotion {
    var fill: CGFloat = 1
    var scale: CGFloat = 1
}
