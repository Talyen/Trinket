import Foundation
import os

enum PlayerSaveMigration {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Trinket",
        category: "PlayerSaveMigration"
    )

    static func migrate(_ save: PlayerSave) -> PlayerSave {
        var current = save
        while current.schemaVersion < PlayerSave.currentSchemaVersion {
            switch current.schemaVersion {
            case 1:
                current = migrateV1ToV2(current)
            default:
                logger.warning(
                    "Unsupported player save schema version \(current.schemaVersion, privacy: .public). Starting fresh."
                )
                return .fresh
            }
        }
        return current
    }

    private static func migrateV1ToV2(_ save: PlayerSave) -> PlayerSave {
        var migrated = save
        if migrated.roster.unlockedHeroIDs.isEmpty, migrated.roster.unlockedPetIDs.isEmpty {
            migrated.roster.unlockedHeroIDs = GameContent.heroes.map(\.id)
            migrated.roster.unlockedPetIDs = GameContent.pets.map(\.id)
        }
        migrated.schemaVersion = 2
        logger.info("Migrated player save from schema v1 to v2.")
        return migrated
    }
}
