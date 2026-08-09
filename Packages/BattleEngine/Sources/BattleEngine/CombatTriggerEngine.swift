import TrinketContent
import TrinketCore

/// Resolves reactions from the unified trait-and-affix trigger profile.
package enum CombatTriggerEngine {
    enum AffixName: String {
        case absolving
        case aetherward
        case arcaneWard = "arcane_ward"
        case beacon
        case bloodPrice = "blood_price"
        case bounty
        case branding
        case cascading
        case disrupting
        case nullifying
        case payday
        case sanctum
        case secondWind = "second_wind"
        case sidestep
        case siphoning
        case symbiosis
        case unmaking
        case untouchable
        case whiplash
    }

    enum TraitFallback: String {
        case bloodfire = "Bloodfire"
        case cutpurse = "Cutpurse"
        case oathbound = "Oathbound"
        case generic = "Trait"
    }

    static func affixName(_ affix: AffixName) -> String {
        GameContent.itemAffixDefinition(matching: affix.rawValue)?.title ?? affix.rawValue
    }

    static func traitName(
        for combatant: Combatant,
        fallback: TraitFallback = .generic,
        in context: BattleState
    ) -> String {
        context.modifiers(for: combatant.id).traitDisplayName ?? fallback.rawValue
    }
}
