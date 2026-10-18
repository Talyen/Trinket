import Foundation
import TrinketContent
import TrinketCore

public struct HomesteadEffectLine: Identifiable, Equatable, Sendable {
    public enum Key: Hashable, Sendable {
        case modifier(AffixModifier, companion: Bool)
        case astralFind
        case forgeAstralOdds
        case archeryAstralOdds
        case goldFind(percent: Bool)
        case experience(percent: Bool)
        case gemsFind(percent: Bool)
        case production(HomesteadResource)
    }

    public let id: Key
    public let label: String
    public let value: String
    public let resource: HomesteadResource?

    public static func lines(for tier: HomesteadNodeTier, nodeID: HomesteadNodeID? = nil) -> [Self] {
        let bonus = tier.combatBonus
        var lines = bonus.heroModifiers.map { line(for: $0, companion: false) }
        lines += bonus.companionModifiers
            .filter { !bonus.heroModifiers.contains($0) }
            .map { line(for: $0, companion: true) }
        if bonus.astralChanceBonusPercent != 0 {
            lines.append(Self(
                id: .astralFind,
                label: String(localized: L10n.ui_homesteadeffectline_astral_drop_rates_7c313),
                value: "\(bonus.astralChanceBonusPercent)%",
                resource: nil,
            ))
        }
        if nodeID == .blacksmithForge {
            let forgeBonus = BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: tier.tier)
            if forgeBonus > 0 {
                lines.append(Self(
                    id: .forgeAstralOdds,
                    label: String(localized: L10n.ui_homesteadeffectline_forge_astral_odds_db78f),
                    value: "\(forgeBonus)%",
                    resource: nil,
                ))
            }
        }
        if nodeID == .archeryRange {
            let bonus = EquipmentRecipe.astralWeightBonusPercent(blacksmithTier: tier.tier)
            if bonus > 0 {
                lines.append(Self(
                    id: .archeryAstralOdds,
                    label: String(localized: L10n.library_range_odds),
                    value: "\(bonus)%",
                    resource: nil,
                ))
            }
        }
        lines += rewardLines(for: bonus)
        for production in tier.production {
            lines.append(Self(
                id: .production(production.resource),
                label: production.resource.displayName,
                value: production.quantity.formatted(),
                resource: production.resource,
            ))
        }
        return lines
    }

    private static func rewardLines(for bonus: HomesteadTierCombatBonus) -> [Self] {
        let rewards: [(Key, String, String, Bool)] = [
            (
                .goldFind(percent: true),
                String(localized: L10n.ui_homesteadeffectline_gold_found_5fc8b),
                "\(bonus.goldFindPercent)%",
                bonus.goldFindPercent != 0,
            ),
            (
                .goldFind(percent: false),
                String(localized: L10n.ui_homesteadeffectline_gold_found_5fc8b),
                "\(bonus.goldFindFlat)",
                bonus.goldFindFlat > 0,
            ),
            (
                .experience(percent: true),
                String(localized: L10n.ui_homesteadeffectline_experience_8eab0),
                "\(bonus.experienceBonusPercent)%",
                bonus.experienceBonusPercent > 0,
            ),
            (
                .experience(percent: false),
                String(localized: L10n.ui_homesteadeffectline_experience_8eab0),
                "\(bonus.experienceBonus)",
                bonus.experienceBonus > 0,
            ),
            (
                .gemsFind(percent: true),
                String(localized: L10n.ui_homesteadeffectline_gems_found_00a7f),
                "\(bonus.gemsFindPercent)%",
                bonus.gemsFindPercent > 0,
            ),
            (
                .gemsFind(percent: false),
                String(localized: L10n.ui_homesteadeffectline_gems_in_encounter_rewards_containing_gems_fe880),
                "\(bonus.gemsFindBonus)",
                bonus.gemsFindBonus > 0,
            ),
        ]
        return rewards.compactMap { key, label, value, enabled in
            enabled ? Self(id: key, label: label, value: value, resource: nil) : nil
        }
    }

    private static func line(for modifier: AffixModifier, companion: Bool) -> Self {
        let label = label(for: modifier)
        let value = modifier.numericValue * (modifier.isPercent ? 100 : 1)
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 2)))
        let scopedLabel: String = if companion, !modifier.isCompanionModifier {
            String(localized: L10n.ui_homesteadeffectline_companion_1_131e7("\(label)"))
        } else if !companion, modifier.isMaximumHealthModifier {
            String(localized: L10n.ui_homesteadeffectline_hero_1_594a0("\(label)"))
        } else {
            label
        }
        return Self(
            id: .modifier(modifier.mapInt { _ in 0 }.mapPercent { _ in 0 }, companion: companion),
            label: scopedLabel,
            value: formatted + (modifier.isPercent ? "%" : ""),
            resource: nil,
        )
    }

    public var description: String {
        switch id {
        case .production:
            String(localized: L10n.ui_homesteadeffectline_produce_1_2_per_day_aefb1("\(value)", "\(label)"))
        case .astralFind: String(localized: L10n.ui_homesteadeffectline_astral_drop_rates_rise_by_1_a8f6b("\(value)"))
        case .forgeAstralOdds: String(localized: L10n.ui_homesteadeffectline_astral_forge_odds_rise_by_1_2efdc("\(value)"))
        case .archeryAstralOdds: String(localized: L10n.library_range_odds_description(value))
        case .goldFind: String(localized: L10n.ui_homesteadeffectline_find_1_more_gold_2d6b4("\(value)"))
        case .experience: String(localized: L10n.ui_homesteadeffectline_gain_1_more_experience_36dd5("\(value)"))
        case .gemsFind: String(localized: L10n.ui_homesteadeffectline_find_1_more_gems_ddc3e("\(value)"))
        case let .modifier(modifier, companion):
            switch modifier {
            case .maximumHealthPercent:
                if companion {
                    String(localized: L10n.ui_homesteadeffectline_companion_health_rises_by_1_fb039("\(value)"))
                } else {
                    String(localized: L10n.ui_homesteadeffectline_increase_hero_health_by_1_b393f("\(value)"))
                }
            case let .damageDealtPercent(keyword, _): String(localized: L10n.ui_homesteadeffectline_increase_1_damage_by_2_71806(
                    "\(keyword.localizedName())",
                    "\(value)",
                ))
            case let .damageTakenPercent(keyword, _): String(localized: L10n.ui_homesteadeffectline_take_1_less_2_damage_431b5(
                    "\(value)",
                    "\(keyword.localizedName())",
                ))
            case .criticalDamagePercent: String(localized: L10n.ui_homesteadeffectline_increase_critical_damage_by_1_07430("\(value)"))
            case .healthRestoredPercent: String(localized: L10n.ui_homesteadeffectline_restore_1_more_health_9892b("\(value)"))
            case .manaRestoredPercent: String(localized: L10n.ui_homesteadeffectline_restore_1_more_mana_eee0e("\(value)"))
            case .leechHealingPercent: String(localized: L10n.ui_homesteadeffectline_leech_restores_1_more_health_01e79("\(value)"))
            case .blockGainedPercent: String(localized: L10n.ui_homesteadeffectline_gain_1_more_block_384cc("\(value)"))
            case .companionDamageDealtPercent: String(localized: L10n.ui_homesteadeffectline_companion_damage_rises_by_1_4f2e4("\(value)"))
            case .dodgeChanceBonus: String(localized: L10n.ui_homesteadeffectline_1_chance_2_98e78("\(label)", "\(displayValue)"))
            case .rangedDamageDealtPercent: String(localized: L10n
                    .ui_homesteadeffectline_bow_and_crossbow_damage_1_69acf("\(displayValue)"))
            default: "\(label) \(displayValue)"
            }
        }
    }

    public var displayValue: String {
        if resource != nil {
            return "+" + value
        }
        if case let .modifier(modifier, _) = id {
            switch modifier {
            case .damageTakenPercent, .damageTakenFlat, .incomingDamageReductionPercent:
                return "−" + value
            default: break
            }
        }
        return "+" + value
    }

    private static func label(for modifier: AffixModifier) -> String {
        switch modifier {
        case .criticalDamage, .criticalDamagePercent: String(localized: L10n.ui_homesteadeffectline_critical_damage_ed30e)
        case .manaRestored, .manaRestoredPercent: String(localized: L10n.ui_homesteadeffectline_mana_restored_775b4)
        case .maximumHealth, .maximumHealthPercent: String(localized: L10n.ui_homesteadeffectline_health_55898)
        case .maximumMana: String(localized: L10n.ui_homesteadeffectline_mana_066ff)
        case let .damageDealt(keyword, _),
             let .damageDealtPercent(
                 keyword,
                 _,
             ): String(localized: L10n.ui_homesteadeffectline_1_damage_a20c7("\(keyword.localizedName())"))
        case .poisonDamageDealtPercent: String(localized: L10n.ui_homesteadeffectline_poison_damage_def9b)
        case .healthRestored, .healthRestoredPercent: String(localized: L10n.ui_homesteadeffectline_health_restored_866e6)
        case .leechGainedPercent: String(localized: L10n.ui_homesteadeffectline_leech_gained_73609)
        case .leechHealing, .leechHealingPercent: String(localized: L10n.ui_homesteadeffectline_leech_healing_dd70e)
        case .goldGained, .goldGainedPercent: String(localized: L10n.ui_homesteadeffectline_gold_gained_68c2f)
        case .blockGained, .blockGainedPercent: String(localized: L10n.ui_homesteadeffectline_block_gained_a07f6)
        case .bleedDuration: String(localized: L10n.ui_homesteadeffectline_bleed_duration_turns_87ff7)
        case let .damageTakenPercent(keyword, _), let .damageTakenFlat(keyword, _), let .damageTakenVulnerability(keyword, _):
            String(localized: L10n.ui_homesteadeffectline_1_damage_taken_f09d1("\(keyword.localizedName())"))
        case .companionDamageDealt, .companionDamageDealtPercent: String(localized: L10n.ui_homesteadeffectline_companion_damage_58009)
        case .companionPhysicalDamageDealt: String(localized: L10n.ui_homesteadeffectline_companion_physical_damage_54ae8)
        case .companionBleedDamageDealt: String(localized: L10n.ui_homesteadeffectline_companion_bleed_damage_a73f8)
        case .outgoingDamagePercent: String(localized: L10n.ui_homesteadeffectline_party_damage_4cc26)
        case .incomingDamageReductionPercent: String(localized: L10n.ui_homesteadeffectline_party_damage_taken_ee076)
        case .dodgeChanceBonus: String(localized: L10n.ui_homesteadeffectline_dodge_9444f)
        case .rangedDamageDealt, .rangedDamageDealtPercent: String(localized: L10n.ui_homesteadeffectline_bow_and_crossbow_damage_999aa)
        case .maximumManaPercent: String(localized: L10n.ui_homesteadeffectline_mana_066ff)
        case .startBattleBlock: String(localized: L10n.ui_homesteadeffectline_starting_block_6a8d9)
        case .attackLeechPercent: String(localized: L10n.ui_homesteadeffectline_attack_leech_81d5c)
        case .attackBlockRemoval: String(localized: L10n.ui_homesteadeffectline_block_removed_on_attack_e8492)
        case .attackPurgeCount: String(localized: L10n.ui_homesteadeffectline_attack_purge_a31f2)
        }
    }
}

private extension AffixModifier {
    var isCompanionModifier: Bool {
        switch self {
        case .companionDamageDealt, .companionDamageDealtPercent, .companionPhysicalDamageDealt, .companionBleedDamageDealt: true
        default: false
        }
    }

    var isMaximumHealthModifier: Bool {
        switch self {
        case .maximumHealth, .maximumHealthPercent: true
        default: false
        }
    }
}
