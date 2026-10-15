import Foundation

public extension Keyword {
    func localizedName(locale: Locale = .current) -> String {
        var resource = nameResource
        resource.locale = locale
        return String(localized: resource)
    }

    func markedName(locale: Locale) -> String {
        "<keyword id=\"\(String(describing: self).lowercased())\">\(localizedName(locale: locale))</keyword>"
    }

    func localizedRules(locale: Locale = .current) -> LocalizedGameText {
        let resource: LocalizedStringResource = switch self {
        case .physical: L10n.keyword_rules_physical
        case .burn: L10n.keyword_rules_burn
        case .stun: L10n.keyword_rules_stun
        case .block: L10n.keyword_rules_block
        case .health: L10n.keyword_rules_health
        case .gold: L10n.keyword_rules_gold
        case .holy: L10n.keyword_rules_holy
        case .poison: L10n.keyword_rules_poison
        case .bleed: L10n.keyword_rules_bleed
        case .leech: L10n.keyword_rules_leech
        case .freeze: L10n.keyword_rules_freeze
        case .dodge: L10n.keyword_rules_dodge
        case .purge: L10n.keyword_rules_purge
        case .cleanse: L10n.keyword_rules_cleanse
        // Keep the English Mana rule aligned with BattleTurnEngine empowerment cost and Effect.manaEmpowermentBonus.
        case .mana: L10n.keyword_rules_mana
        case .deathsDoor: L10n.keyword_rules_deathsdoor
        case .thorns: L10n.keyword_rules_thorns
        }
        return LocalizedGameText(resource, locale: locale)
    }

    var nameResource: LocalizedStringResource {
        switch self {
        case .physical: L10n.keyword_name_physical
        case .burn: L10n.keyword_name_burn
        case .stun: L10n.keyword_name_stun
        case .block: L10n.keyword_name_block
        case .health: L10n.keyword_name_health
        case .gold: L10n.keyword_name_gold
        case .holy: L10n.keyword_name_holy
        case .poison: L10n.keyword_name_poison
        case .bleed: L10n.keyword_name_bleed
        case .leech: L10n.keyword_name_leech
        case .freeze: L10n.keyword_name_freeze
        case .dodge: L10n.keyword_name_dodge
        case .purge: L10n.keyword_name_purge
        case .cleanse: L10n.keyword_name_cleanse
        case .mana: L10n.keyword_name_mana
        case .deathsDoor: L10n.keyword_name_deathsdoor
        case .thorns: L10n.keyword_name_thorns
        }
    }
}
