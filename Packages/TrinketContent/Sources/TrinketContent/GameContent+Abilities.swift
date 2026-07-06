import Foundation
import TrinketCore

extension GameContent {
    /// Canonical ability lookup. All runtime ability resolution should route here
    /// rather than importing tier-specific `AbilityCatalog*` modules directly.
    public static func ability(id: String) -> Ability? {
        AbilityCatalog.ability(id: id)
    }

    /// Every ability shipped in the game, merged from manifest-generated and hand-authored tiers.
    public static var abilities: [Ability] {
        AbilityCatalog.all
    }
}
