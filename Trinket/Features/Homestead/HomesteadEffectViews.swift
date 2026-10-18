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
        .gameAccessibilityLabel(resource.displayName)
        .accessibilityValue(isInsufficient ? String(localized: L10n.ui_homesteadeffectviews_1_insufficient_a0bcb("\(value)")) : value)
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
        if let resource = effect.resource, let range = text.range(of: ContentCopy.localized(resource.displayName)) {
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
                GameLabel(title)
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
    // swiftlint:disable:next function_body_length - Keep the exhaustive node and benefit identity mapping together for localized titles
    static func title(nodeID: HomesteadNodeID, effect: HomesteadEffectLine) -> String {
        switch (nodeID, effect.id) {
        case (.wheatField, .modifier(.maximumHealthPercent, _)): String(localized: L10n.ui_homesteadeffectviews_harvest_s_strength_86a7b)
        case (.wheatField, .production(.food)): String(localized: L10n.ui_homesteadeffectviews_golden_harvest_7d1b8)
        case (
            .herbGarden,
            .modifier(.damageTakenPercent(.poison, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_bitter_remedy_6e9c2)
        case (.herbGarden, .production(.herbs)): String(localized: L10n.ui_homesteadeffectviews_fresh_pickings_97ebc)
        case (.chickenCoop, .modifier(.maximumHealthPercent, _)): String(localized: L10n.ui_homesteadeffectviews_coop_s_comfort_126d0)
        case (.chickenCoop, .production(.food)): String(localized: L10n.ui_homesteadeffectviews_morning_eggs_e0c43)
        case (.pasture, .modifier(.damageTakenPercent(.physical, _), _)): String(localized: L10n.ui_homesteadeffectviews_thick_hide_1e0e8)
        case (.pasture, .production(.hide)): String(localized: L10n.ui_homesteadeffectviews_gathered_hides_68fd6)
        case (.culinaryArts, .modifier(.healthRestoredPercent, _)): String(localized: L10n.ui_homesteadeffectviews_hearty_fare_a4413)
        case (.culinaryArts, .production(.food)): String(localized: L10n.ui_homesteadeffectviews_daily_bread_ca0de)
        case (
            .blacksmithForge,
            .modifier(.damageDealtPercent(.physical, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_forged_edge_ecc89)
        case (.blacksmithForge, .forgeAstralOdds): String(localized: L10n.ui_homesteadeffectviews_astral_forging_fe216)
        case (.blacksmithForge, .production(.iron)): String(localized: L10n.ui_homesteadeffectviews_fresh_ingots_04643)
        case (
            .woolTailoring,
            .modifier(.damageTakenPercent(.freeze, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_winter_weave_38b6f)
        case (
            .woolTailoring,
            .modifier(.damageTakenPercent(.burn, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_emberguard_stitch_b1f27)
        case (.woolTailoring, .production(.gold)): String(localized: L10n.ui_homesteadeffectviews_tailor_s_trade_feec0)
        case (
            .runesmithWorkshop,
            .modifier(.damageDealtPercent(.freeze, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_frost_inscription_58bdd)
        case (
            .runesmithWorkshop,
            .modifier(.damageDealtPercent(.holy, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_hallowed_script_c4580)
        case (.runesmithWorkshop, .production(.gems)): String(localized: L10n.ui_homesteadeffectviews_runic_crystals_1b067)
        case (
            .alchemyLab,
            .modifier(.damageDealtPercent(.poison, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_potent_venom_58b8c)
        case (.alchemyLab, .production(.herbs)): String(localized: L10n.ui_homesteadeffectviews_cultured_reagents_d437e)
        case (.crystalGarden, .modifier(.criticalDamagePercent, _)): String(localized: L10n.ui_homesteadeffectviews_perfect_facet_99ce2)
        case (.crystalGarden, .production(.gems)): String(localized: L10n.ui_homesteadeffectviews_crystal_bloom_89fbd)
        case (.crystalGarden, .production(.stone)): String(localized: L10n.ui_homesteadeffectviews_mineral_growth_403c4)
        case (
            .transmutationCrucible,
            .modifier(.damageDealtPercent(.burn, _), _),
        ): String(localized: L10n.ui_homesteadeffectviews_alchemical_flame_945a1)
        case (.transmutationCrucible, .production(.iron)): String(localized: L10n.ui_homesteadeffectviews_metal_transmutation_be829)
        case (.mycologyCellar, .modifier(.leechHealingPercent, _)): String(localized: L10n.ui_homesteadeffectviews_siphoning_spores_92593)
        case (.mycologyCellar, .production(.herbs)): String(localized: L10n.ui_homesteadeffectviews_fungal_harvest_128e3)
        case (.hunterLodge, .modifier(.companionDamageDealtPercent, _)): String(localized: L10n.ui_homesteadeffectviews_pack_instinct_b9668)
        case (.hunterLodge, .production(.hide)): String(localized: L10n.ui_homesteadeffectviews_hunter_s_haul_16745)
        case (.agilityTraining, .modifier(.dodgeChanceBonus, _)): String(localized: L10n.ui_homesteadeffectviews_nimble_paws_b09ad)
        case (.sparringGrounds, .modifier(.blockGainedPercent, _)): String(localized: L10n.ui_homesteadeffectviews_steady_guard_12531)
        case (.sparringGrounds, .production(.iron)): String(localized: L10n.ui_homesteadeffectviews_salvaged_steel_33438)
        case (.archeryRange, .modifier(.rangedDamageDealtPercent, _)): String(localized: L10n.ui_homesteadeffectviews_true_aim_5fde2)
        case (.archeryRange, .production(.wood)): String(localized: L10n.ui_homesteadeffectviews_seasoned_timber_6e1d3)
        case (.moonlitSanctum, .astralFind): String(localized: L10n.ui_homesteadeffectviews_astral_attunement_82aed)
        case (.moonlitSanctum, .gemsFind): String(localized: L10n.ui_homesteadeffectviews_moonlit_fortune_18d3c)
        case (.wishingWell, .goldFind): String(localized: L10n.ui_homesteadeffectviews_wishful_fortune_fb2cf)
        case (.wishingWell, .production(.gold)): String(localized: L10n.ui_homesteadeffectviews_wishing_coins_e05d5)
        case (.library, .experience): String(localized: L10n.ui_homesteadeffectviews_lessons_of_the_past_fe7da)
        case (.leylineEnergy, .modifier(.manaRestoredPercent, _)): String(localized: L10n.ui_homesteadeffectviews_arcane_renewal_dfef9)
        case (.leylineEnergy, .production(.gems)): String(localized: L10n.ui_homesteadeffectviews_leyline_crystallization_1fb32)
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
        .accessibilityLabel(Text(L10n.ui_homesteadeffectviews_building_progress_904de))
        .accessibilityValue(Text(L10n.ui_homesteadeffectviews_1_of_2_upgrades_67fe8("\(currentTier)", "\(totalTiers)")))
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
        case .astralFind, .forgeAstralOdds, .archeryAstralOdds:
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
