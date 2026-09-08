import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRosterGenerated.heroes
    static let companions = GameContentRosterGenerated.companions
    static let combatants: [Combatant] = heroes + companions
    static let enemies: [Enemy] = GameContentEnemiesGenerated.enemies

    private static let combatantsByID: [String: Combatant] = Dictionary(
        uniqueKeysWithValues: combatants.map { ($0.id, $0) },
    )

    private static let enemiesByID: [String: Enemy] = Dictionary(
        uniqueKeysWithValues: enemies.map { ($0.id, $0) },
    )

    static func combatant(matching id: String) -> Combatant? {
        combatantsByID[id]
    }

    static func enemy(matching id: String) -> Enemy? {
        enemiesByID[id]
    }

    static var nonBossEnemies: [Enemy] {
        enemies.filter { !$0.isBoss }
    }

    static func pickRandomNonBossEnemyID(forStageID stageID: String, worldSeed: UInt64) -> String? {
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "random-battle-\(stageID)"),
        )
        return nonBossEnemies
            .map(\.id)
            .randomElement(using: &randomNumberGenerator)
    }
}
