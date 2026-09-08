import Foundation
import SwiftData
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Model
final class LegacyPrimaryStatsRow {
    var combatantID: String = ""
    var wisdom: Int = 0

    init(combatantID: String = "", wisdom: Int = 0) {
        self.combatantID = combatantID
        self.wisdom = wisdom
    }
}

struct PlayerSaveSchemaMigrationTests {
    @Test @MainActor func `store migrates when current schema removes an entity`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let legacySchema = Schema(PlayerSaveSchema.models + [LegacyPrimaryStatsRow.self])
        try SaveTestSupport.writeRoot(.testSeed, to: storeURL, schema: legacySchema) { context in
            context.insert(LegacyPrimaryStatsRow(combatantID: "knight", wisdom: 7))
        }
        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: ModelConfiguration(schema: legacySchema, url: storeURL, cloudKitDatabase: .none),
        )
        let legacyCount = try ModelContext(legacyContainer).fetch(FetchDescriptor<LegacyPrimaryStatsRow>()).count
        try #require(legacyCount == 1)

        let migratedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(!migratedStore.isPersistenceDegraded)
        try #expect(migratedStore.currentSave.schemaVersion == PlayerSave.currentSchemaVersion)
        try #expect(migratedStore.roster == .testSeed)
        try #expect(migratedStore.inventory == .testSeed)
        try #expect(migratedStore.journey == .testSeed)
        try #expect(migratedStore.homestead == .testSeed)
        try #expect(migratedStore.spires == .testSeed)
        try #expect(migratedStore.labyrinth.worldSeed == migratedStore.worldSeed)
        try #expect(migratedStore.contracts == .freshStart)

        let reloaded = try context.makeReloadedStore()
        try #expect(!reloaded.isPersistenceDegraded)
        try #expect(reloaded.currentSave == migratedStore.currentSave)
    }
}
