import Foundation
import SwiftData
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PlayerSaveStoreCleanupTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `clean store files deletes sqlite sidecars`() throws {
        let storeURL = context.storeURL()
        do {
            _ = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
                persistSaveImmediately: true,
            )
        }
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        try Data([0x1]).write(to: walURL)
        try Data([0x1]).write(to: shmURL)

        PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL)

        try #expect(!FileManager.default.fileExists(atPath: storeURL.path))
        try #expect(!FileManager.default.fileExists(atPath: walURL.path))
        try #expect(!FileManager.default.fileExists(atPath: shmURL.path))
    }

    @Test func `reset state true wipes prior progress`() throws {
        let storeURL = context.storeURL()
        do {
            let store = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
                persistSaveImmediately: true,
            )
            var roster = store.roster
            roster.gold = 99
            store.roster = roster
        }

        _ = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            resetState: true,
            persistSaveImmediately: true,
        )

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == PlayerRosterState.freshStart.gold)
        try #expect(primaryRootCount(at: storeURL) == 1)
    }

    @Test func `duplicate primary roots keep the newest on open`() throws {
        let storeURL = context.storeURL()
        do {
            let firstStore = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
                persistSaveImmediately: true,
            )
            var roster = firstStore.roster
            roster.gold = 99
            firstStore.roster = roster
        }

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let stale = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
        stale.modifiedAt = .distantPast
        sideContext.insert(stale)
        try sideContext.save()

        let reopened = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reopened.roster.gold == 99)
        try #expect(primaryRootCount(at: storeURL) == 1)
    }

    @Test func `duplicate primary roots with equal modified at keep higher session generation`() throws {
        let storeURL = context.storeURL()
        let timestamp = Date()
        do {
            let firstStore = try PlayerSaveStore(
                storeURL: storeURL,
                disableCloudSync: true,
                persistSaveImmediately: true,
            )
            var roster = firstStore.roster
            roster.gold = 99
            firstStore.roster = roster
        }

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let primaries = try sideContext.fetch(
            FetchDescriptor<PlayerSaveRoot>(predicate: #Predicate { $0.id == "primary" }),
        )
        let keeper = try #require(primaries.first)
        keeper.modifiedAt = timestamp
        keeper.sessionGeneration = 4

        let stale = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
        stale.modifiedAt = timestamp
        stale.sessionGeneration = 1
        sideContext.insert(stale)
        try sideContext.save()

        let reopened = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reopened.roster.gold == 99)
        try #expect(reopened.currentSave.sessionGeneration == 4)
        try #expect(primaryRootCount(at: storeURL) == 1)
    }

    private func primaryRootCount(at storeURL: URL) throws -> Int {
        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        return try sideContext.fetch(
            FetchDescriptor<PlayerSaveRoot>(predicate: #Predicate { $0.id == "primary" }),
        ).count
    }
}
