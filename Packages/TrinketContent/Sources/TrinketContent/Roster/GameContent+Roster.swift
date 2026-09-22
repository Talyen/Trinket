import Foundation
import TrinketCore

public extension GameContent {
    static let heroes = GameContentRosterGenerated.heroes
    static let companions = GameContentRosterGenerated.companions
    static let combatants: [Combatant] = heroes + companions
    static let enemies: [Enemy] = GameContentEnemiesGenerated.enemies

    private static let heroesByID: [String: Combatant] = Dictionary(
        uniqueKeysWithValues: heroes.map { ($0.id, $0) },
    )

    private static let companionsByID: [String: Combatant] = Dictionary(
        uniqueKeysWithValues: companions.map { ($0.id, $0) },
    )

    private static let combatantsByID: [String: Combatant] = Dictionary(
        uniqueKeysWithValues: combatants.map { ($0.id, $0) },
    )

    private static let enemiesByID: [String: Enemy] = Dictionary(
        uniqueKeysWithValues: enemies.map { ($0.id, $0) },
    )

    static func hero(matching id: String) -> Combatant? {
        heroesByID[id]
    }

    static func companion(matching id: String) -> Combatant? {
        companionsByID[id]
    }

    static func combatant(matching id: String) -> Combatant? {
        combatantsByID[id]
    }

    static func enemy(matching id: String) -> Enemy? {
        enemiesByID[id]
    }

    static let bossEnemies: [Enemy] = enemies.filter(\.isBoss)
    static let nonBossEnemies: [Enemy] = enemies.filter { !$0.isBoss }
    static let bossEnemyIDs: [String] = bossEnemies.map(\.id)
    static let nonBossEnemyIDs: [String] = nonBossEnemies.map(\.id)

    static func pickRandomNonBossEnemyID(forStageID stageID: String, worldSeed: UInt64) -> String? {
        var randomNumberGenerator = SeededRandomNumberGenerator(
            seed: encounterSeed(worldSeed, salt: "random-battle-\(stageID)"),
        )
        return nonBossEnemyIDs.randomElement(using: &randomNumberGenerator)
    }
}
