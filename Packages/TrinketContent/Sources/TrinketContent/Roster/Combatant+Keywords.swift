import Foundation
import TrinketCore

public extension Combatant {
    var keywordProfile: Set<Keyword> {
        var keywords = Set<Keyword>()
        for abilities in [abilityChoices.basics, abilityChoices.skills, abilityChoices.ultimates] {
            for ability in abilities {
                keywords.formUnion(ability.identityKeywords)
            }
        }
        return keywords
    }

    var affinityKeywords: [Keyword] {
        CombatantTalentCatalog.combatantTreeAffinities[id]?.map(\.keyword) ?? []
    }
}
