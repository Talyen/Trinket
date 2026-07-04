import Foundation
import TrinketCore

public extension Combatant {
    /// Keywords implied by every ability option in this combatant's loadout pool.
    var keywordProfile: Set<Keyword> {
        let abilities = abilityChoices.basics
            + abilityChoices.skills
            + abilityChoices.ultimates
        return Set(abilities.flatMap(\.keywords))
    }
}
