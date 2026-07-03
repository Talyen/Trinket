import Foundation
import TrinketCore

public extension GameContent {
    public static let heroes = GameContentRoster.heroes
    public static let pets = GameContentRoster.pets
    public static let enemies: [Enemy] = GameContentEnemies.enemies

    public static func enemy(matching id: String) -> Enemy? {
        enemies.first { $0.id == id }
    }
}

public extension Combatant {
    public static var heroes: [Combatant] {
        GameContent.heroes
    }

    public static var pets: [Combatant] {
        GameContent.pets
    }

    public static var enemies: [Enemy] {
        GameContent.enemies
    }
}
