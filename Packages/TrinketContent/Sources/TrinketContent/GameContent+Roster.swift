import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRoster.heroes
    static let companions = GameContentRoster.companions
    static let enemies: [Enemy] = GameContentEnemies.enemies

    static var starterHeroes: [Combatant] {
        heroes
    }

    static var starterCompanions: [Combatant] {
        companions
    }

    static var starterHeroIDs: [String] {
        heroes.map(\.id)
    }

    static var starterCompanionIDs: [String] {
        companions.map(\.id)
    }

    static func enemy(matching id: String) -> Enemy? {
        GameContentEnemies.enemiesByID[id]
    }
}
