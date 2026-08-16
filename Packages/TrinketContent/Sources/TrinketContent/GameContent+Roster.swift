import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRoster.heroes
    static let companions = GameContentRoster.companions
    static let enemies: [Enemy] = GameContentEnemies.enemies

    static func enemy(matching id: String) -> Enemy? {
        GameContentEnemies.enemiesByID[id]
    }
}
