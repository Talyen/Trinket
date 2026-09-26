import Foundation
import TrinketCore

public enum LabyrinthCatalog {
    public static let trashEnemyIDs: [String] = GameContent.nonBossEnemyIDs
    public static let bossEnemyIDs: [String] = GameContent.bossEnemyIDs

    public static func pickBossEnemyID(
        excluding previousBossID: String?,
        using rng: inout some RandomNumberGenerator,
    ) -> String {
        let pool = bossEnemyIDs.filter { $0 != previousBossID }
        let choices = pool.isEmpty ? bossEnemyIDs : pool
        return choices.randomElement(using: &rng) ?? bossEnemyIDs[0]
    }

    public static func pickTrashEnemyID(using rng: inout some RandomNumberGenerator) -> String {
        trashEnemyIDs.randomElement(using: &rng) ?? trashEnemyIDs[0]
    }

    public static func fallbackBossEnemyID(worldSeed: UInt64, nodeID: String) -> String {
        let pool = bossEnemyIDs
        let index = Int(
            GameContent.encounterSeed(worldSeed, salt: "labyrinth-boss-\(nodeID)") % UInt64(pool.count),
        )
        return pool[index]
    }
}
