import Foundation
import TrinketCore

public enum AbilityCatalog {
    public static let all: [Ability] = basicAbilities + skillAbilities + ultimateAbilities

    public static func ability(id: String) -> Ability? {
        abilitiesByID[id]
    }

    private static let abilitiesByID: [String: Ability] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) },
    )
}
