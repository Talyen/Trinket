import Foundation
import TrinketCore

public extension GameContent {
    /// Canonical ability lookup. All runtime ability resolution should route here
    /// rather than importing tier-specific `AbilityCatalog*` modules directly.
    static func ability(id: String) -> Ability? {
        AbilityCatalog.ability(id: id)
    }

    /// Every ability shipped in the game, merged from manifest-generated and hand-authored tiers.
    static var abilities: [Ability] {
        AbilityCatalog.all
    }
}
