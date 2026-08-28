import Foundation
import TrinketCore

public extension GameContent {
    static func ability(id: String) -> Ability? {
        AbilityCatalog.ability(id: id)
    }

    static var abilities: [Ability] {
        AbilityCatalog.all
    }
}
