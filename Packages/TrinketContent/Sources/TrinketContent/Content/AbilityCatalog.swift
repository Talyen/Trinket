import Foundation
import TrinketCore

public enum AbilityCatalog {
    public static let all: [Ability] =
        AbilityCatalogBasic.all
            + AbilityCatalogSkill.all
            + AbilityCatalogUltimate.all

    public static func ability(id: String) -> Ability? {
        AbilityCatalogIndexGenerated.abilitiesByID[id]
    }
}
