import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRoster.heroes
    static let companions = GameContentRoster.companions
    static let enemies: [Enemy] = GameContentEnemies.enemies

    static let starterHeroIDs = ["knight", "rogue", "wizard"]
    static let starterCompanionIDs = ["wolf", "panther", "frost_whelp"]

    static var starterHeroes: [Combatant] {
        starterHeroIDs.compactMap { id in heroes.first { $0.id == id } }
    }

    static var starterCompanions: [Combatant] {
        starterCompanionIDs.compactMap { id in companions.first { $0.id == id } }
    }

    static func enemy(matching id: String) -> Enemy? {
        GameContentEnemies.enemiesByID[id]
    }
}
