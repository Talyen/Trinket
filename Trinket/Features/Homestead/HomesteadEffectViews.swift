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
        .accessibilityIdentifier(AccessibilityID.Homestead.resourceCost(resource))
    }
}

struct HomesteadBenefitsView: View {
    let nodeID: HomesteadNodeID
    let tier: HomesteadNodeTier
    let effectsIdentifier: String
    var highlightedEffects: Set<HomesteadEffectLine.Key> = []
    var highlightsProduction = false

    private var lines: [HomesteadEffectLine] {
        HomesteadEffectLine.lines(for: tier, nodeID: nodeID)
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
            isHighlighted: effect.resource == nil ? highlightedEffects.contains(effect.id) : highlightsProduction,
        )
    }
}

private struct HomesteadBenefitItem: View {
    let title: String
    let effect: HomesteadEffectLine
    let isHighlighted: Bool

    private var description: AttributedString {
        var text = KeywordDescriptionText.attributedText(for: effect.description)
        if let range = text.range(of: effect.value) {
            text[range].inlinePresentationIntent = .stronglyEmphasized
            text[range].foregroundColor = isHighlighted ? TrinketDesign.Colors.accent : .primary
        }
        if let resource = effect.resource, let range = text.range(of: resource.displayName) {
            text[range].inlinePresentationIntent = .stronglyEmphasized
            text[range].foregroundColor = resource.productionNameColor
        }
        return text
    }

    var body: some View {
        HStack(alignment: .top, spacing: TrinketDesign.Spacing.small) {
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
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.extraSmall) {
                Text(title)
                    .trinketTypography(.rowTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .trinketTypography(.body)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum HomesteadBenefitNames {
    static func title(nodeID: HomesteadNodeID, effect: HomesteadEffectLine) -> String {
        switch (nodeID, effect.id) {
        case (.wheatField, .modifier(.maximumHealthPercent, _)): "Harvest’s Strength"
        case (.wheatField, .production(.food)): "Golden Harvest"
        case (.herbGarden, .modifier(.damageTakenPercent(.poison, _), _)): "Bitter Remedy"
        case (.herbGarden, .production(.herbs)): "Fresh Pickings"
        case (.chickenCoop, .modifier(.maximumHealthPercent, _)): "Coop’s Comfort"
        case (.chickenCoop, .production(.food)): "Morning Eggs"
        case (.pasture, .modifier(.damageTakenPercent(.physical, _), _)): "Thick Hide"
        case (.pasture, .production(.hide)): "Gathered Hides"
        case (.culinaryArts, .modifier(.healthRestoredPercent, _)): "Hearty Fare"
        case (.culinaryArts, .production(.food)): "Daily Bread"
        case (.blacksmithForge, .modifier(.damageDealtPercent(.physical, _), _)): "Forged Edge"
        case (.blacksmithForge, .forgeAstralOdds): "Astral Forging"
        case (.blacksmithForge, .production(.iron)): "Fresh Ingots"
        case (.woolTailoring, .modifier(.damageTakenPercent(.freeze, _), _)): "Winter Weave"
        case (.woolTailoring, .modifier(.damageTakenPercent(.burn, _), _)): "Emberguard Stitch"
        case (.woolTailoring, .production(.gold)): "Tailor’s Trade"
        case (.runesmithWorkshop, .modifier(.damageDealtPercent(.freeze, _), _)): "Frost Inscription"
        case (.runesmithWorkshop, .modifier(.damageDealtPercent(.holy, _), _)): "Hallowed Script"
        case (.runesmithWorkshop, .production(.gems)): "Runic Crystals"
        case (.alchemyLab, .modifier(.damageDealtPercent(.poison, _), _)): "Potent Venom"
        case (.alchemyLab, .production(.herbs)): "Cultured Reagents"
        case (.crystalGarden, .modifier(.criticalDamagePercent, _)): "Perfect Facet"
        case (.crystalGarden, .production(.gems)): "Crystal Bloom"
        case (.crystalGarden, .production(.stone)): "Mineral Growth"
        case (.transmutationCrucible, .modifier(.damageDealtPercent(.burn, _), _)): "Alchemical Flame"
        case (.transmutationCrucible, .production(.iron)): "Metal Transmutation"
        case (.mycologyCellar, .modifier(.leechHealingPercent, _)): "Siphoning Spores"
        case (.mycologyCellar, .production(.herbs)): "Fungal Harvest"
        case (.hunterLodge, .modifier(.companionDamageDealtPercent, _)): "Pack Instinct"
        case (.hunterLodge, .production(.hide)): "Hunter’s Haul"
        case (.agilityTraining, .modifier(.dodgeChanceBonus, _)): "Nimble Paws"
        case (.sparringGrounds, .modifier(.blockGainedPercent, _)): "Steady Guard"
        case (.sparringGrounds, .production(.iron)): "Salvaged Steel"
        case (.archeryRange, .modifier(.rangedDamageDealtPercent, _)): "True Aim"
        case (.archeryRange, .production(.wood)): "Seasoned Timber"
        case (.moonlitSanctum, .astralFind): "Astral Attunement"
        case (.moonlitSanctum, .gemsFind): "Moonlit Fortune"
        case (.wishingWell, .goldFind): "Wishful Fortune"
        case (.wishingWell, .production(.gold)): "Wishing Coins"
        case (.library, .experience): "Lessons of the Past"
        case (.leylineEnergy, .modifier(.manaRestoredPercent, _)): "Arcane Renewal"
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
        case .astralFind, .forgeAstralOdds:
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
        case .maximumHealth, .maximumHealthPercent:
            self.init(keyword: .health)
        case .healthRestored, .healthRestoredPercent:
            self.init(keyword: .health, symbol: "heart.circle.fill")
        case .criticalDamage, .criticalDamagePercent:
            self.init(keyword: .physical, symbol: "scope")
        case .manaRestored, .manaRestoredPercent, .maximumMana, .maximumManaPercent:
            self.init(keyword: .mana)
        case let .damageDealt(keyword, _), let .damageDealtPercent(keyword, _):
            self.init(keyword: keyword)
        case .poisonDamageDealtPercent:
            self.init(keyword: .poison)
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            self.init(keyword: keyword, symbol: "shield.fill")
        case .incomingDamageReductionPercent, .blockGained, .blockGainedPercent, .startBattleBlock, .attackBlockRemoval:
            self.init(keyword: .block)
        case .outgoingDamagePercent:
            self.init(keyword: .physical)
        case .rangedDamageDealt, .rangedDamageDealtPercent:
            self.init(keyword: .physical, symbol: "figure.archery")
        case .companionDamageDealt, .companionDamageDealtPercent, .companionPhysicalDamageDealt:
            self.init(keyword: .physical, symbol: "pawprint.fill")
        case .dodgeChanceBonus:
            self.init(keyword: .dodge)
        case .leechGainedPercent, .leechHealing, .leechHealingPercent, .attackLeechPercent:
            self.init(keyword: .leech)
        case .attackPurgeCount:
            self.init(keyword: .purge)
        case .goldGained, .goldGainedPercent:
            self.init(keyword: .gold)
        case .bleedDuration, .companionBleedDamageDealt:
            self.init(keyword: .bleed)
        }
    }
}
