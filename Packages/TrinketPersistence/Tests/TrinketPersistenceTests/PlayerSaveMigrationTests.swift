import XCTest
import BattleEngine
import TrinketContent
@testable import TrinketPersistence

@MainActor
final class PlayerSaveMigrationTests: XCTestCase {
    func testFreshSaveUsesKnightAndBearStarters() {
        let save = PlayerSave.fresh

        XCTAssertEqual(save.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertEqual(save.roster.unlockedHeroIDs, [PlayerRosterState.starterHeroID])
        XCTAssertEqual(save.roster.unlockedPetIDs, [PlayerRosterState.starterPetID])
        XCTAssertEqual(save.roster.activeHeroID, PlayerRosterState.starterHeroID)
        XCTAssertEqual(save.roster.activePetID, PlayerRosterState.starterPetID)
    }

    func testMigrateV1SaveUnlocksAllLegacyCombatants() {
        let v1Roster = SavedRosterState(
            activeHeroID: "knight",
            activePetID: "wolf",
            unlockedHeroIDs: [],
            unlockedPetIDs: [],
            abilityLoadouts: [:],
            progressions: ["knight": .initial],
            equipmentLoadouts: [:],
            gold: 12
        )
        let v1Save = PlayerSave(
            schemaVersion: 1,
            modifiedAt: .distantPast,
            journey: .initial,
            roster: v1Roster,
            inventory: SavedInventoryState(.freshStart)
        )

        let migrated = PlayerSaveMigration.migrate(v1Save)

        XCTAssertEqual(migrated.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertEqual(Set(migrated.roster.unlockedHeroIDs), Set(GameContent.heroes.map(\.id)))
        XCTAssertEqual(Set(migrated.roster.unlockedPetIDs), Set(GameContent.pets.map(\.id)))
        XCTAssertEqual(migrated.roster.gold, 12)
        XCTAssertEqual(migrated.homestead.homestead(), .freshStart)
    }

    func testLoadV1JSONFromDiskMigratesToCurrentSchema() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerSaveMigrationTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let v1JSON = """
        {
          "schemaVersion": 1,
          "journey": {
            "activeChapterID": "chapter-1",
            "activeStageID": "chapter-1-stage-1",
            "completedStageIDs": [],
            "claimedRewardStageIDs": [],
            "lastCompletedStageID": null
          },
          "roster": {
            "activeHeroID": "knight",
            "activePetID": "bear",
            "abilityLoadouts": {},
            "progressions": {
              "knight": { "level": 2, "currentXP": 10, "requiredXP": 120 }
            },
            "equipmentLoadouts": {},
            "gold": 5
          },
          "inventory": { "items": [] }
        }
        """
        let fileStore = PlayerSaveFileStore(directoryURL: directoryURL)
        try v1JSON.write(to: fileStore.saveFileURL, atomically: true, encoding: .utf8)

        let loaded = try XCTUnwrap(fileStore.load())
        let store = PlayerSaveStore(fileStore: fileStore)

        XCTAssertEqual(loaded.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertNotEqual(loaded.modifiedAt, .distantPast)
        XCTAssertEqual(Set(store.roster.unlockedHeroIDs), Set(GameContent.heroes.map(\.id)))
        XCTAssertEqual(store.roster.progression(for: GameContent.heroes[0]).currentXP, 10)
    }

    func testInvalidAbilityIDFallsBackToCombatantDefault() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        var saved = SavedAbilityLoadout(knight.abilityLoadout)
        saved.skillID = "missing-ability"

        let resolved = saved.loadout(
            defaults: knight.abilityLoadout,
            choices: knight.abilityChoices
        )

        XCTAssertEqual(resolved.skill?.id, knight.abilityLoadout.skill?.id)
    }

    func testSanitizeClampsActivePartyToUnlockedStarters() {
        var roster = SavedRosterState(
            activeHeroID: "wizard",
            activePetID: "wolf",
            unlockedHeroIDs: [PlayerRosterState.starterHeroID],
            unlockedPetIDs: [PlayerRosterState.starterPetID],
            abilityLoadouts: [:],
            progressions: [:],
            equipmentLoadouts: [:],
            gold: 0
        )

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventoryItemIDs: [])
        let playerRoster = sanitized.roster(inventoryItemIDs: [])

        XCTAssertEqual(playerRoster.activeHeroID, PlayerRosterState.starterHeroID)
        XCTAssertEqual(playerRoster.activePetID, PlayerRosterState.starterPetID)
    }

    func testMigrateV1SavePreservesPartialUnlocks() {
        let v1Roster = SavedRosterState(
            activeHeroID: "knight",
            activePetID: "bear",
            unlockedHeroIDs: ["knight", "wizard"],
            unlockedPetIDs: ["bear"],
            abilityLoadouts: [:],
            progressions: ["knight": .initial],
            equipmentLoadouts: [:],
            gold: 8
        )
        let v1Save = PlayerSave(
            schemaVersion: 1,
            modifiedAt: .distantPast,
            journey: .initial,
            roster: v1Roster,
            inventory: SavedInventoryState(.freshStart)
        )

        let migrated = PlayerSaveMigration.migrate(v1Save)

        XCTAssertEqual(migrated.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertEqual(Set(migrated.roster.unlockedHeroIDs), ["knight", "wizard"])
        XCTAssertEqual(migrated.roster.unlockedPetIDs, ["bear"])
        XCTAssertEqual(migrated.roster.gold, 8)
    }

    func testUnsupportedSchemaVersionReturnsFresh() {
        let unsupported = PlayerSave(
            schemaVersion: 0,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.testSeed),
            inventory: SavedInventoryState(.testSeed)
        )

        let migrated = PlayerSaveMigration.migrate(unsupported)

        XCTAssertEqual(migrated.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertEqual(migrated.journey, .initial)
        XCTAssertEqual(migrated.roster, SavedRosterState(.freshStart))
        XCTAssertEqual(migrated.inventory, SavedInventoryState(.freshStart))
        XCTAssertEqual(migrated.homestead, SavedHomesteadState(.freshStart))
    }

    func testMigrateV2ToV3StampsModifiedAt() {
        let v2Save = PlayerSave(
            schemaVersion: 2,
            modifiedAt: .distantPast,
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )

        let migrated = PlayerSaveMigration.migrate(v2Save)

        XCTAssertEqual(migrated.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertNotEqual(migrated.modifiedAt, .distantPast)
    }

    func testMigrateV4ToV5AddsFreshHomestead() {
        let v4Save = PlayerSave(
            schemaVersion: 4,
            modifiedAt: Date(),
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )

        let migrated = PlayerSaveMigration.migrate(v4Save)

        XCTAssertEqual(migrated.schemaVersion, PlayerSave.currentSchemaVersion)
        XCTAssertEqual(migrated.homestead.homestead(), .freshStart)
    }
}
