import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

enum LibraryCopy {
    static func localized(_ resource: LocalizedStringResource, locale: Locale) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }

    static func title(_ id: String, locale: Locale) -> String {
        switch id {
        case "forest-field-notes": localized(L10n.library_project_forest, locale: locale)
        case "predator-anatomy": localized(L10n.library_project_predator, locale: locale)
        case "arms-and-armor": localized(L10n.library_project_arms, locale: locale)
        case "serrated-steel": localized(L10n.homestead_project_serrated_steel, locale: locale)
        case "consecrated-arms": localized(L10n.homestead_project_consecrated_arms, locale: locale)
        case "shieldcraft": localized(L10n.homestead_project_shieldcraft, locale: locale)
        case "reinforced-leather": localized(L10n.homestead_project_reinforced_leather, locale: locale)
        case "venomproof-leather": localized(L10n.homestead_project_venomproof_leather, locale: locale)
        case "sanguine-leather": localized(L10n.homestead_project_sanguine_leather, locale: locale)
        default: localized(L10n.library_research, locale: locale)
        }
    }

    static func recipe(_ recipe: EquipmentRecipe, locale: Locale) -> String {
        switch recipe.id {
        case "archery-shortbow-poison": localized(L10n.library_recipe_poison, locale: locale)
        case "archery-longbow-bleed": localized(L10n.library_recipe_bleed, locale: locale)
        case "archery-crossbow-physical": localized(L10n.library_recipe_physical, locale: locale)
        case "blacksmith-greatsword-bleed": localized(L10n.homestead_recipe_bleed_greatsword, locale: locale)
        case "blacksmith-mace-holy": localized(L10n.homestead_recipe_holy_mace, locale: locale)
        case "blacksmith-kite-shield-block": localized(L10n.homestead_recipe_block_shield, locale: locale)
        case "outfitter-leather-armor-block": localized(L10n.homestead_recipe_block_leather, locale: locale)
        case "outfitter-leather-armor-poison": localized(L10n.homestead_recipe_poison_leather, locale: locale)
        case "outfitter-leather-armor-leech": localized(L10n.homestead_recipe_leech_leather, locale: locale)
        default: recipe.baseType.localizedName(locale: locale)
        }
    }

    static func guarantee(_ recipe: EquipmentRecipe, locale: Locale) -> String {
        switch recipe.requiredKeyword {
        case .poison: localized(L10n.library_guarantee_poison, locale: locale)
        case .bleed: localized(L10n.library_guarantee_bleed, locale: locale)
        case .physical: localized(L10n.library_guarantee_physical, locale: locale)
        case .holy: localized(L10n.homestead_guarantee_holy, locale: locale)
        case .block: localized(L10n.homestead_guarantee_block, locale: locale)
        case .leech: localized(L10n.homestead_guarantee_leech, locale: locale)
        default: ""
        }
    }

    static func tier(_ number: Int, locale: Locale) -> String {
        let numeral = ["I", "II", "III", "IV"][min(3, max(0, number - 1))]
        return localized(L10n.library_tier(numeral), locale: locale)
    }

    static func progress(_ completed: Int, total: Int, locale: Locale) -> String {
        localized(L10n.library_progress(completed, total), locale: locale)
    }

    static func openWorkshop(_ recipe: EquipmentRecipe, locale: Locale) -> String {
        switch recipe.buildingID {
        case .blacksmithForge: localized(L10n.homestead_open_blacksmith, locale: locale)
        case .woolTailoring: localized(L10n.homestead_open_outfitter, locale: locale)
        default: localized(L10n.library_open_range, locale: locale)
        }
    }
}

struct LibraryRecipePreview: View {
    @Environment(ShellSession.self) private var shell
    @Namespace private var resultNamespace
    let recipe: EquipmentRecipe

    var body: some View {
        BlacksmithForgePreview(
            recipe: recipe,
            resultNamespace: resultNamespace,
            onOpenResult: { _, _ in },
            onViewResearch: { LibraryNavigation.open(.researchProject($0), in: shell) },
            readOnly: true,
            onOpenWorkshop: { LibraryNavigation.open(.workshop(recipe.id), in: shell) },
        )
    }
}
