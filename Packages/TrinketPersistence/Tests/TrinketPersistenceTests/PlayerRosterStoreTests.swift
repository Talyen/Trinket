import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@MainActor
final class PlayerRosterStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func mutateRosterPersistsThroughHub() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
        )
        let persisted = firstStore.mutateRoster {
            $0.gold = 17
        }
        try #expect(persisted)
        try #expect(firstStore.roster.gold == 17)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 17)
    }
}
