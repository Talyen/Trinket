import Foundation
import TrinketCore

public extension Combatant {
    var keywordProfile: Set<Keyword> {
        let abilities = abilityChoices.basics
            + abilityChoices.skills
            + abilityChoices.ultimates
        return Set(abilities.flatMap(\.keywords))
    }
}
