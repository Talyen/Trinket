import Foundation

enum AbilityCatalog {
    static let all: [Ability] =
        AbilityCatalogBasic.all
            + AbilityCatalogSkill.all
            + AbilityCatalogUltimate.all

    static func ability(id: String) -> Ability? {
        all.first { $0.id == id }
    }
}
