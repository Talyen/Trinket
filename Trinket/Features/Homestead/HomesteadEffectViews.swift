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
    let nodeID: HomesteadNodeID
    let tier: HomesteadNodeTier
    let effectsIdentifier: String
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []
    var highlightsProduction = false

    var previousTier: HomesteadNodeTier?

    private var lines: [HomesteadEffectLine] {
        HomesteadEffectLine.lines(for: tier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
            ForEach(lines) { effect in
                item(effect)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(effectsIdentifier)
    }

    private func item(_ effect: HomesteadEffectLine) -> some View {
        HomesteadBenefitItem(
            title: HomesteadBenefitNames.title(nodeID: nodeID, effect: effect),
            effect: effect,
            previousEffect: previousTier.flatMap { previous in
                HomesteadEffectLine.lines(for: previous).first { $0.id == effect.id }
            },
            isHighlighted: effect.resource == nil ? highlightedEffects.contains(effect.id) : highlightsProduction,
        )
    }
}

private struct HomesteadBenefitItem: View {
    let title: String
    let effect: HomesteadEffectLine
    let previousEffect: HomesteadEffectLine?
    let isHighlighted: Bool

    private var displayedValue: String {
        if let previousEffect, previousEffect.value != effect.value {
            return "\(previousEffect.displayValue) → \(effect.displayValue)"
        }
        return effect.displayValue
    }

    private var description: AttributedString {
        var value = AttributedString(displayedValue)
        value.inlinePresentationIntent = .stronglyEmphasized
        value.foregroundColor = isHighlighted ? TrinketDesign.Colors.accent : .primary
        if let resource = effect.resource {
            var output = AttributedString(" \(resource.displayName)")
            output.inlinePresentationIntent = .stronglyEmphasized
            return value + output + AttributedString(" per Day")
        }
        if effect.id == .gemsFind {
            return value + AttributedString(" ") + KeywordDescriptionText.attributedText(for: effect.label)
        }
        return KeywordDescriptionText.attributedText(for: effect.label) + AttributedString(" ") + value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            HStack(spacing: TrinketDesign.Spacing.small) {
                Group {
                    if let resource = effect.resource {
                        HomesteadResourceArtwork(resource: resource)
                    } else {
                        let style = HomesteadEffectStyle(key: effect.id)
                        Image(systemName: style.symbol)
                            .symbolRenderingMode(.monochrome)
                            .trinketTypography(.sectionTitle)
                            .foregroundStyle(style.tint)
                    }
                }
                .frame(width: 36, height: 36)
                .accessibilityHidden(true)
                Text(title)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(description)
                .trinketTypography(.rowTitle)
                .fontWeight(.regular)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
                .scaleEffect(isHighlighted ? 1.03 : 1, anchor: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum HomesteadBenefitNames {
    static func title(nodeID: HomesteadNodeID, effect: HomesteadEffectLine) -> String {
        switch (nodeID, effect.id) {
        case (.wheatField, .modifier(.maximumHealth, _)): "Harvest’s Strength"
        case (.wheatField, .production(.food)): "Golden Harvest"
        case (.herbGarden, .modifier(.damageTakenFlat(.poison, _), _)): "Bitter Remedy"
        case (.herbGarden, .production(.herbs)): "Fresh Pickings"
        case (.chickenCoop, .modifier(.maximumHealth, _)): "Coop’s Comfort"
        case (.chickenCoop, .production(.food)): "Morning Eggs"
        case (.pasture, .modifier(.damageTakenFlat(.physical, _), _)): "Thick Hide"
        case (.pasture, .production(.hide)): "Gathered Hides"
        case (.culinaryArts, .modifier(.healthRestored, _)): "Hearty Fare"
        case (.culinaryArts, .production(.food)): "Daily Bread"
        case (.blacksmithForge, .modifier(.damageDealt(.physical, _), _)): "Forged Edge"
        case (.blacksmithForge, .production(.iron)): "Fresh Ingots"
        case (.woolTailoring, .modifier(.damageTakenFlat(.freeze, _), _)): "Winter Weave"
        case (.woolTailoring, .modifier(.damageTakenFlat(.burn, _), _)): "Emberguard Stitch"
        case (.woolTailoring, .production(.gold)): "Tailor’s Trade"
        case (.runesmithWorkshop, .modifier(.damageDealt(.freeze, _), _)): "Frost Inscription"
        case (.runesmithWorkshop, .modifier(.damageDealt(.holy, _), _)): "Hallowed Script"
        case (.runesmithWorkshop, .production(.gems)): "Runic Crystals"
        case (.alchemyLab, .modifier(.damageDealt(.poison, _), _)): "Potent Venom"
        case (.alchemyLab, .production(.herbs)): "Cultured Reagents"
        case (.crystalGarden, .modifier(.criticalDamage, _)): "Perfect Facet"
        case (.crystalGarden, .production(.gems)): "Crystal Bloom"
        case (.crystalGarden, .production(.stone)): "Mineral Growth"
        case (.transmutationCrucible, .modifier(.damageDealt(.burn, _), _)): "Alchemical Flame"
        case (.transmutationCrucible, .production(.iron)): "Metal Transmutation"
        case (.mycologyCellar, .modifier(.leechHealing, _)): "Siphoning Spores"
        case (.mycologyCellar, .production(.herbs)): "Fungal Harvest"
        case (.hunterLodge, .modifier(.companionDamageDealt, _)): "Pack Instinct"
        case (.hunterLodge, .production(.hide)): "Hunter’s Haul"
        case (.agilityTraining, .modifier(.dodgeChanceBonus, _)): "Nimble Paws"
        case (.sparringGrounds, .modifier(.blockGained, _)): "Steady Guard"
        case (.sparringGrounds, .production(.iron)): "Salvaged Steel"
        case (.archeryRange, .modifier(.rangedDamageDealt, _)): "True Aim"
        case (.archeryRange, .production(.wood)): "Seasoned Timber"
        case (.moonlitSanctum, .astralFind): "Astral Attunement"
        case (.moonlitSanctum, .gemsFind): "Moonlit Fortune"
        case (.wishingWell, .goldFind): "Wishful Fortune"
        case (.wishingWell, .production(.gold)): "Wishing Coins"
        case (.library, .experience): "Lessons of the Past"
        case (.leylineEnergy, .modifier(.manaRestored, _)): "Arcane Renewal"
        case (.leylineEnergy, .production(.gems)): "Leyline Crystallization"
        default: effect.resource?.displayName ?? effect.label
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
        case .experience:
            self.init(symbol: "book.fill", tint: TrinketDesign.Colors.arcane)
        case .gemsFind:
            self.init(symbol: "diamond.fill", tint: TrinketDesign.Colors.arcane)
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
        case .criticalDamage:
            self.init(keyword: .physical, symbol: "scope")
        case .manaRestored, .maximumMana, .maximumManaPercent:
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
