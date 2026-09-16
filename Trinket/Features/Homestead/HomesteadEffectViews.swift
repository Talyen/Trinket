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

    var previousTier: HomesteadNodeTier?

    var body: some View {
        HomesteadBenefitsLayout(allowsColumns: tier.production != nil) {
            ForEach(HomesteadEffectLine.lines(for: tier)) { effect in
                HomesteadBenefitItem(
                    effect: effect,
                    previousEffect: previousTier.flatMap { previous in
                        HomesteadEffectLine.lines(for: previous).first { $0.id == effect.id }
                    },
                    isHighlighted: effect.resource == nil ? highlightedEffects.contains(effect.id) : highlightsProduction,
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(effectsIdentifier)
    }
}

private struct HomesteadBenefitItem: View {
    let effect: HomesteadEffectLine
    let previousEffect: HomesteadEffectLine?
    let isHighlighted: Bool

    private var displayedValue: String {
        if let previousEffect, previousEffect.value != effect.value {
            return "\(previousEffect.displayValue) → \(effect.displayValue)"
        }
        return effect.displayValue
    }

    var body: some View {
        let style = HomesteadEffectStyle(key: effect.id)
        HStack(spacing: TrinketDesign.Spacing.small) {
            Image(systemName: style.symbol)
                .symbolRenderingMode(.monochrome)
                .trinketTypography(.rowTitle)
                .fontWeight(.semibold)
                .foregroundStyle(style.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                Text(effect.resource?.displayName ?? "Bonus")
                    .trinketTypography(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.extraSmall) {
                    if effect.resource == nil {
                        Text(KeywordDescriptionText.attributedText(for: effect.label))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(displayedValue)
                        .bold()
                        .foregroundStyle(isHighlighted ? TrinketDesign.Colors.accent : .primary)
                        .contentTransition(.numericText())
                        .scaleEffect(isHighlighted ? 1.08 : 1, anchor: .leading)
                        .fixedSize()
                    if effect.resource != nil {
                        Text("per day")
                            .fixedSize()
                    }
                }
                .trinketTypography(.body)
                .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomesteadBenefitsLayout: Layout {
    let allowsColumns: Bool
    private let spacing = TrinketDesign.Spacing.medium

    private func columnWidth(for width: CGFloat, subviews: Subviews) -> CGFloat? {
        guard allowsColumns, subviews.count == 2 else { return nil }
        let column = max(0, (width - spacing) / 2)
        return subviews.allSatisfy { $0.sizeThatFits(.unspecified).width <= column } ? column : nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let column = columnWidth(for: width, subviews: subviews)
        let heights = subviews.map { $0.sizeThatFits(.init(width: column ?? width, height: nil)).height }
        let height = column == nil
            ? heights.reduce(0, +) + CGFloat(max(0, subviews.count - 1)) * spacing
            : heights.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let column = columnWidth(for: bounds.width, subviews: subviews)
        let childProposal = ProposedViewSize(width: column ?? bounds.width, height: nil)
        var origin = bounds.origin
        for subview in subviews {
            subview.place(at: origin, anchor: .topLeading, proposal: childProposal)
            if let column {
                origin.x += column + spacing
            } else {
                origin.y += subview.sizeThatFits(childProposal).height + spacing
            }
        }
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

/// Symbol/tint mapping for effect lines. Lives with its single call site
/// (`HomesteadBenefitItem`) rather than in a standalone file.
private struct HomesteadEffectStyle {
    let symbol: String
    let tint: Color

    init(key: HomesteadEffectLine.Key) {
        switch key {
        case let .modifier(modifier, _):
            self.init(modifier: modifier)
        case .astralFind:
            self.init(symbol: "sparkles", tint: TrinketDesign.Colors.arcane)
        case .goldFind:
            self.init(keyword: .gold)
        case let .production(resource):
            self.init(symbol: Self.symbol(for: resource), tint: resource.tint)
        }
    }

    private init(symbol: String, tint: Color) {
        self.symbol = symbol
        self.tint = tint
    }

    private init(keyword: Keyword, symbol: String? = nil) {
        self.init(symbol: symbol ?? keyword.visualStyle.icon.symbolName, tint: keyword.visualStyle.color)
    }

    private init(modifier: AffixModifier) {
        switch modifier {
        case .maximumHealth:
            self.init(keyword: .health)
        case .healthRestored:
            self.init(keyword: .health, symbol: "heart.circle.fill")
        case .maximumMana:
            self.init(keyword: .mana)
        case let .damageDealt(keyword, _):
            self.init(keyword: keyword)
        case .poisonDamageDealtPercent:
            self.init(keyword: .poison)
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            self.init(keyword: keyword, symbol: "shield.fill")
        case .incomingDamageReductionPercent, .blockGained:
            self.init(keyword: .block)
        case .outgoingDamagePercent:
            self.init(keyword: .physical)
        case .companionDamageDealt, .companionPhysicalDamageDealt:
            self.init(keyword: .physical, symbol: "pawprint.fill")
        case .dodgeChanceBonus:
            self.init(keyword: .dodge)
        case .leechGainedPercent, .leechHealing:
            self.init(keyword: .leech)
        case .goldGained, .goldGainedPercent:
            self.init(keyword: .gold)
        case .bleedDuration, .companionBleedDamageDealt:
            self.init(keyword: .bleed)
        }
    }

    private static func symbol(for resource: HomesteadResource) -> String {
        switch resource {
        case .food: "carrot.fill"
        case .herbs: "leaf.fill"
        case .crystal: "diamond.fill"
        case .hide: "square.stack.3d.up.fill"
        case .gold: "circle.circle.fill"
        case .wood: "tree.fill"
        case .stone: "mountain.2.fill"
        case .iron: "anvil.fill"
        }
    }
}
