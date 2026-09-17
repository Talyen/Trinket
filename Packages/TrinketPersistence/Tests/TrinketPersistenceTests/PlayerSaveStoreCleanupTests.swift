import Foundation
import SwiftData
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveStoreCleanupTests {
    @Test @MainActor func `cloud duplicate roots are preserved without choosing or repairing either save`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let original = try context.makeSaveStore()
        #expect(original.persistBatch(logging: "Test setup") { $0.roster.gold = 99 })
        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let other = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
        other.modifiedAt = .distantPast
        sideContext.insert(other)
        try sideContext.save()
        let before = try sideContext.fetch(FetchDescriptor<PlayerSaveRoot>()).map { $0.toPlayerSave() }

        #expect(throws: PlayerSavePersistenceError.self) {
            _ = try PlayerSaveStore(
                openResult: .init(
                    container: sideContext.container,
                    usedInMemoryFallback: false,
                ),
                cloudSyncEnabled: true,
            )
        }

        let reloadedContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let after = try reloadedContext.fetch(FetchDescriptor<PlayerSaveRoot>()).map { $0.toPlayerSave() }
        #expect(after.count == 2)
        #expect(before.allSatisfy { after.contains($0) })
    }

    @Test(arguments: ["PlayerSave.sqlite", "default.store", "save"])
    func `clean store files removes only the store and its sidecars`(filename: String) throws {
        let context = try PersistenceTestContext()
        let storeURL = context.directoryURL.appendingPathComponent(filename)
        let storeFiles = [filename, "\(filename)-wal", "\(filename)-shm", "\(filename)-journal"]
        let unrelatedFiles = ["\(filename).wal", "\(filename).shm", "\(filename).journal", "other.store"]
        for name in storeFiles + unrelatedFiles {
            try Data([0x1]).write(to: context.directoryURL.appendingPathComponent(name))
        }

        try PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL)
        try PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL)

        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: context.directoryURL.path)
        #expect(Set(remainingFiles) == Set(unrelatedFiles))
    }

    @Test @MainActor func `reset state true wipes prior progress`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        do {
            let store = try context.makeSaveStore()
            var roster = store.roster
            roster.gold = 99
            #expect(store.persistBatch(logging: "Test setup") { $0.roster = roster })
        }

        _ = try context.makeSaveStore(resetState: true)

        let reloaded = try context.makeReloadedStore()
        try #expect(reloaded.roster.gold == PlayerRosterState.freshStart.gold)
        try #expect(primaryRootCount(at: storeURL) == 1)
    }

    @Test @MainActor func `duplicate primary roots keep the newest on open`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        do {
            let firstStore = try context.makeSaveStore()
            var roster = firstStore.roster
            roster.gold = 99
            #expect(firstStore.persistBatch(logging: "Test setup") { $0.roster = roster })
        }

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let stale = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
        stale.modifiedAt = .distantPast
        sideContext.insert(stale)
        try sideContext.save()

        let reopened = try context.makeReloadedStore()
        try #expect(reopened.roster.gold == 99)
        try #expect(primaryRootCount(at: storeURL) == 1)
    }

    @Test @MainActor func `duplicate primary roots with equal modified at keep higher session generation`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let timestamp = Date()
        do {
            let firstStore = try context.makeSaveStore()
            var roster = firstStore.roster
            roster.gold = 99
            #expect(firstStore.persistBatch(logging: "Test setup") { $0.roster = roster })
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

        let reopened = try context.makeReloadedStore()
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
