import Foundation
import os
import TrinketContent

public enum PlayerSaveMigration {
    private static let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSaveMigration"
    )

    public static func migrate(_ save: PlayerSave) -> PlayerSave {
        var current = save
        while current.schemaVersion < PlayerSave.currentSchemaVersion {
            switch current.schemaVersion {
            case 1:
                current = migrateV1ToV2(current)
            case 2:
                current = migrateV2ToV3(current)
            case 3:
                current = migrateV3ToV4(current)
            case 4:
                current = migrateV4ToV5(current)
            case 5:
                current = migrateV5ToV6(current)
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

    private static func migrateV2ToV3(_ save: PlayerSave) -> PlayerSave {
        var migrated = save
        if migrated.modifiedAt == .distantPast {
            migrated.modifiedAt = Date()
        }
        migrated.schemaVersion = 3
        logger.info("Migrated player save from schema v2 to v3.")
        return migrated
    }

    private static func migrateV3ToV4(_ save: PlayerSave) -> PlayerSave {
        var migrated = save
        migrated.roster = SavedRosterState(
            activeHeroID: migrated.roster.activeHeroID,
            activePetID: migrated.roster.activePetID,
            unlockedHeroIDs: migrated.roster.unlockedHeroIDs,
            unlockedPetIDs: migrated.roster.unlockedPetIDs,
            abilityLoadouts: migrated.roster.abilityLoadouts,
            progressions: migrated.roster.progressions,
            equipmentLoadouts: migrated.roster.equipmentLoadouts,
            gold: migrated.roster.gold,
            primaryStats: [:]
        )
        migrated.schemaVersion = 4
        logger.info("Migrated player save from schema v3 to v4.")
        return migrated
    }

    private static func migrateV4ToV5(_ save: PlayerSave) -> PlayerSave {
        var migrated = save
        migrated.homestead = SavedHomesteadState(.freshStart)
        migrated.schemaVersion = 5
        logger.info("Migrated player save from schema v4 to v5.")
        return migrated
    }

    private static func migrateV5ToV6(_ save: PlayerSave) -> PlayerSave {
        var migrated = save
        migrated.sessionGeneration = 0
        migrated.schemaVersion = 6
        logger.info("Migrated player save from schema v5 to v6.")
        return migrated
    }
}
