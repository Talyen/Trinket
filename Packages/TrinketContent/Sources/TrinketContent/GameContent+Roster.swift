import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRoster.heroes
    static let companions = GameContentRoster.companions
    static let combatants: [Combatant] = heroes + companions
    static let enemies: [Enemy] = GameContentEnemies.enemies

    private static let combatantsByID: [String: Combatant] = Dictionary(
        uniqueKeysWithValues: combatants.map { ($0.id, $0) },
    )

    static func combatant(matching id: String) -> Combatant? {
        combatantsByID[id]
    }

    static func enemy(matching id: String) -> Enemy? {
        GameContentEnemies.enemiesByID[id]
    }
}
