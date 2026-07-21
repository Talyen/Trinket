import Foundation
import TrinketCore

/// Aggregates every ability tier from `Content/AbilityCatalog{Basic,Skill,Ultimate}.swift`.
/// Author abilities only in those tier files (use `AbilityBuilder` for repeated shapes).
/// After edits, run `./Scripts/generate.sh` to refresh shorthand and
/// `Generated/AbilityInventory.generated.tsv` (id, name, tier, summary for humans/agents).
public enum AbilityCatalog {
    public static let all: [Ability] =
        AbilityCatalogBasic.all
            + AbilityCatalogSkill.all
            + AbilityCatalogUltimate.all

    public static func ability(id: String) -> Ability? {
        if let indexed = AbilityCatalogIndexGenerated.abilitiesByID[id] {
            return indexed
        }
        return all.first { $0.id == id }
    }
}
