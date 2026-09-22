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
        let pendingName = PendingSaveRecovery.url(for: storeURL).lastPathComponent
        let recoveryFiles = [
            pendingName,
            PendingSaveRecovery.url(for: storeURL, kind: .previous).lastPathComponent,
            "\(pendingName).unreadable", "\(pendingName).unreadable.2",
            "\(pendingName).unreadable.16", "\(pendingName).unreadable.999",
        ]
        let unrelatedFiles = [
            "\(filename).wal", "\(filename).shm", "\(filename).journal", "other.store",
            "\(pendingName).unreadable.note", "\(pendingName).unreadable.1",
        ]
        for name in storeFiles + recoveryFiles + unrelatedFiles {
            try Data([0x1]).write(to: context.directoryURL.appendingPathComponent(name))
        }
        let unrelatedDirectory = context.directoryURL.appendingPathComponent("\(pendingName).unreadable.1000")
        try FileManager.default.createDirectory(at: unrelatedDirectory, withIntermediateDirectories: false)

        try PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL)
        try PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL)

        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: context.directoryURL.path)
        #expect(Set(remainingFiles) == Set(unrelatedFiles + [unrelatedDirectory.lastPathComponent]))
    }

    @Test func `archive pruning includes sparse and high suffixes`() throws {
        let context = try PersistenceTestContext()
        let pendingURL = PendingSaveRecovery.url(for: context.storeURL())
        let names = ["", ".2", ".3", ".4", ".5", ".16", ".999"]
        let archives = try names.enumerated().map { index, suffix in
            let url = URL(fileURLWithPath: pendingURL.path + ".unreadable" + suffix)
            try Data([0x1]).write(to: url)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(index + 1) * 100)],
                ofItemAtPath: url.path,
            )
            return url
        }
        let unrelated = URL(fileURLWithPath: pendingURL.path + ".unreadable.note")
        try Data([0x1]).write(to: unrelated)

        PendingSaveRecovery.pruneCorruptSamples(forPendingURL: pendingURL)

        #expect(archives.prefix(2).allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(archives.dropFirst(2).allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @Test func `store cleanup without recovery leaves all recovery files`() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let pendingURL = PendingSaveRecovery.url(for: storeURL)
        let archiveURL = URL(fileURLWithPath: pendingURL.path + ".unreadable.16")
        try Data([0x1]).write(to: pendingURL)
        try Data([0x1]).write(to: archiveURL)

        try PlayerSaveStoreConfiguration.cleanStoreFiles(at: storeURL, includingRecovery: false)

        #expect(FileManager.default.fileExists(atPath: pendingURL.path))
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
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
