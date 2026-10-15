import Foundation

/// Presentation lookup for canonical domain labels; raw values remain save identities.
public enum CoreCopy {
    public static func description(_ english: String, locale: Locale = .current) -> LocalizedGameText {
        if let keyword = Keyword.allCases.first(where: { $0.rulesText == english }) {
            return keyword.localizedRules(locale: locale)
        }
        if let keyword = Keyword.allCases.first(where: { $0.rawValue == english }) {
            return LocalizedGameText(markedText: keyword.markedName(locale: locale))
        }
        let rendered = LocalizedGameText(resource(english), locale: locale)
        if let keyword = Keyword.allCases.first(where: { $0.statusAlias == english }) {
            return LocalizedGameText(markedText: "<keyword id=\"\(String(describing: keyword).lowercased())\">\(rendered.text)</keyword>")
        }
        return rendered
    }

    public static func resource(_ english: String) -> LocalizedStringResource {
        if let keyword = Keyword.allCases.first(where: { $0.rawValue == english }) {
            return keyword.nameResource
        }
        return switch english {
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
