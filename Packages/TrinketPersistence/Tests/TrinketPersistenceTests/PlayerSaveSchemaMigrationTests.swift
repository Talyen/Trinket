import Foundation
import SwiftData
import Testing
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSchemaMigrationTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    /// Proves V1 stores open through the V2 lightweight migration (dropped
    /// `JourneyProgressModel.lastCompletedStageID` and related unused columns).
    @Test func migratesPlayerSaveSchemaV1ToV2() throws {
        let storeURL = context.storeURL()
        do {
            let v1Schema = Schema(versionedSchema: PlayerSaveSchemaV1.self)
            let container = try ModelContainer(
                for: v1Schema,
                configurations: ModelConfiguration(
                    schema: v1Schema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
            )
            let modelContext = ModelContext(container)
            modelContext.insert(PlayerSaveRoot(save: .testSeed))
            try modelContext.save()
        }

        let migrated = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(!migrated.isPersistenceDegraded)
        try #expect(migrated.roster == .testSeed)
        try #expect(migrated.journey.activeChapterID == JourneyProgressState.initial.activeChapterID)
    }
}
