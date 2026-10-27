import Foundation

/// Presentation lookup for canonical domain labels; raw values remain save identities.
public enum CoreCopy {
    /// Canonical English is locale-independent; render only the matched rule
    /// in the caller's locale rather than rendering every rule for each lookup.
    private static let keywordByRulesText = Dictionary(
        Keyword.allCases.map { ($0.rulesText, $0) },
        uniquingKeysWith: { first, _ in first },
    )

    private static let keywordByStatusAlias = Dictionary(
        Keyword.allCases.lazy.compactMap { keyword in keyword.statusAlias.map { ($0, keyword) } },
        uniquingKeysWith: { first, _ in first },
    )

    public static func description(_ english: String, locale: Locale = .current) -> LocalizedGameText {
        if let keyword = keywordByRulesText[english] {
            return keyword.localizedRules(locale: locale)
        }
        if let keyword = Keyword(rawValue: english) {
            return LocalizedGameText(markedText: keyword.markedName(locale: locale))
        }
        let rendered = LocalizedGameText(resource(english), locale: locale)
        if let keyword = keywordByStatusAlias[english] {
            return LocalizedGameText(markedText: "<keyword id=\"\(String(describing: keyword).lowercased())\">\(rendered.text)</keyword>")
        }
        return rendered
    }

    public static func resource(_ english: String) -> LocalizedStringResource {
        if let keyword = Keyword(rawValue: english) {
            return keyword.nameResource
        }
        return switch english {
        case "Weapon": L10n.label_weapon
        case "Armor": L10n.label_armor
        case "Accessory": L10n.label_accessory
        case "Trinket": L10n.label_trinket
        case "Farming": L10n.label_farming
        case "Crafting": L10n.label_crafting
        case "Alchemy": L10n.label_alchemy
        case "Training": L10n.label_training
        case "Arcana": L10n.label_arcana
        case "treasure": L10n.label_treasure
        case "Burning": L10n.keyword_status_burn
        case "Poisoned": L10n.keyword_status_poison
        case "Bleeding": L10n.keyword_status_bleed
        case "Frozen": L10n.keyword_status_freeze
        case "Stunned": L10n.keyword_status_stun
        case "Play": L10n.label_play
        case "Collection": L10n.label_collection
        case "Homestead": L10n.label_homestead
        case "Options": L10n.label_options
        case "Hero": L10n.label_hero
        case "Companion": L10n.label_companion
        case "Basic": L10n.label_basic
        case "Skill": L10n.label_skill
        case "Ultimate": L10n.label_ultimate
        case "Astral": L10n.label_astral
        case "Unique": L10n.label_unique
        case "Damage Type": L10n.label_damage_type
        case "Mitigation": L10n.label_mitigation
        case "Restoration": L10n.label_restoration
        case "Resource": L10n.label_resource
        default: LocalizedStringResource(String.LocalizationValue(stringLiteral: english))
        }
    }
}
