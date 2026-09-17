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

    private var lines: [HomesteadEffectLine] {
        HomesteadEffectLine.lines(for: tier)
    }

    var body: some View {
        Group {
            if tier.production != nil, lines.count == 2 {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: TrinketDesign.Spacing.medium) {
                        item(lines[0])
                            .frame(maxWidth: .infinity, alignment: .leading)
                        item(lines[1])
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    stackedItems
                }
            } else {
                stackedItems
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(effectsIdentifier)
    }

    private var stackedItems: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.medium) {
            ForEach(lines) { effect in
                item(effect)
            }
        }
    }

    private func item(_ effect: HomesteadEffectLine) -> some View {
        HomesteadBenefitItem(
            effect: effect,
            previousEffect: previousTier.flatMap { previous in
                HomesteadEffectLine.lines(for: previous).first { $0.id == effect.id }
            },
            isHighlighted: effect.resource == nil ? highlightedEffects.contains(effect.id) : highlightsProduction,
        )
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
            self.init(symbol: resource.icon.symbolName, tint: resource.tint)
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
        case .maximumMana, .maximumManaPercent:
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
        case .rangedDamageDealt:
            self.init(keyword: .physical, symbol: "figure.archery")
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
}
