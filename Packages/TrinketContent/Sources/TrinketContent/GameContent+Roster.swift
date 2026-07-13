import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRoster.heroes
    static let companions = GameContentRoster.companions
    static let enemies: [Enemy] = GameContentEnemies.enemies

    static func enemy(matching id: String) -> Enemy? {
        enemies.first { $0.id == id }
    }
}

public extension Combatant {
    static var heroes: [Combatant] {
        GameContent.heroes
    }

    static var companions: [Combatant] {
        GameContent.companions
    }

    static var enemies: [Enemy] {
        GameContent.enemies
    }
}
