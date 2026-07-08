import Foundation
import TrinketCore

/// Aggregates every ability tier. Manifest-generated abilities live in
/// `Generated/AbilityCatalog*.generated.swift`; complex hand-authored abilities
/// live in `Content/AbilityCatalog*.swift`. Add simple abilities via
/// `ContentManifest/abilities.tsv` and run `./Scripts/generate.sh`.
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
