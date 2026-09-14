import Foundation
import Testing
import TrinketCore
@testable import TrinketPersistence

@MainActor
struct PendingSaveRecoveryTests {
    @Test func `database failure preserves progress across relaunch`() throws {
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try context.makeSaveStore()
        original?.forcesNextDatabaseSaveFailure = true
        let didSave = original?.persistBatch(logging: "Recovery fixture") { save in
            save.roster.gold = 73
            save.roster.progressions[save.roster.activeHeroID] = .at(level: 4)
        }
        #expect(didSave == true)
        let expected = try #require(original?.currentSave)
        let recoveryURL = PendingSaveRecovery.url(for: context.storeURL())
        #expect(FileManager.default.fileExists(atPath: recoveryURL.path))
        original = nil
        let restored = try context.makeReloadedStore()
        #expect(restored.currentSave == expected)
        #expect(!FileManager.default.fileExists(atPath: recoveryURL.path))
        #expect(!restored.isPersistenceDegraded)
    }

    @Test func `recovery keeps latest complete save and account metadata together`() throws {
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try context.makeSaveStore()
        original?.forcesNextDatabaseSaveFailure = true
        _ = original?.persistBatch(logging: "Recovery fixture") { $0.roster.gold = 17 }
        var account = CloudDeviceState()
        account.activeAccountID = "next-account"
        var next = PlayerSave.fresh
        next.roster.gold = 29
        original?.forcesNextDatabaseSaveFailure = true
        try original?.commitCloudState(account, replacing: next)
        let expected = try #require(original?.currentSave)
        original = nil
        let restored = try context.makeReloadedStore()
        #expect(restored.currentSave == expected)
        #expect(restored.cloudDeviceState.activeAccountID == "next-account")
    }

    @Test func `explicit reset does not restore an older pending save`() throws {
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try context.makeSaveStore()
        original?.forcesNextDatabaseSaveFailure = true
        _ = original?.persistBatch(logging: "Recovery fixture") { $0.roster.gold = 73 }
        original = nil
        let reset = try context.makeSaveStore(resetState: true)
        #expect(reset.roster.gold == PlayerSave.fresh.roster.gold)
        #expect(!FileManager.default.fileExists(atPath: PendingSaveRecovery.url(for: context.storeURL()).path))
    }

    @Test(arguments: [false, true])
    func `recovery reset keeps pending progress until reset is durable`(fails: Bool) throws {
        let context = try PersistenceTestContext()
        try Data("unreadable database".utf8).write(to: context.storeURL())
        var saved = PlayerSave.fresh
        saved.roster.gold = 42
        var metadata = CloudDeviceState()
        metadata.activeAccountID = "account"
        try PendingSaveRecovery(storeURL: context.storeURL()).write(save: saved, cloudState: JSONEncoder().encode(metadata))
        var store: PlayerSaveStore? = try context.makeSaveStore()
        store?.forcesNextSaveFailure = fails
        if fails {
            #expect(throws: PlayerSavePersistenceError.writeFailed) { try store?.resetGameplayProgress() }
        } else {
            try store?.resetGameplayProgress()
        }
        store = nil
        let restored = try context.makeReloadedStore()
        #expect(restored.roster.gold == (fails ? 42 : 0))
        #expect(restored.cloudDeviceState.account.resetRequested == !fails)
    }

    @Test func `recovery reset keeps pending progress when database write fails`() throws {
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try context.makeSaveStore()
        original?.forcesNextDatabaseSaveFailure = true
        _ = original?.persistBatch(logging: "Recovery fixture") { $0.roster.gold = 42 }
        original?.forcesNextDatabaseSaveFailure = true
        #expect(throws: PlayerSavePersistenceError.writeFailed) { try original?.resetGameplayProgress() }
        let recoveryURL = PendingSaveRecovery.url(for: context.storeURL())
        #expect(FileManager.default.fileExists(atPath: recoveryURL.path))
        original = nil
        let restored = try context.makeReloadedStore()
        #expect(restored.roster.gold == 42)
        #expect(!restored.cloudDeviceState.account.resetRequested)
    }

    @Test func `database recovery retries in the background`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        store.forcesNextDatabaseSaveFailure = true
        #expect(store.persistBatch(logging: "Recovery fixture") { $0.roster.gold = 47 })
        for _ in 0 ..< 300 where store.isPersistenceDegraded {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isPersistenceDegraded)
        #expect(try context.makeReloadedStore().roster.gold == 47)
    }

    @Test(arguments: [false, true])
    func `pending action retries once and cannot cross reset`(reset: Bool) async throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        store.forcesNextSaveFailure = true
        #expect(!store.persistBatch(logging: "Retry fixture") { $0.roster.gold += 3 })
        var attempts = 0
        store.retrySaveAction(key: "claim") { [weak store] in
            attempts += 1
            _ = store?.persistBatch(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        store.retrySaveAction(key: "claim") { attempts += 100 }
        if reset {
            try store.resetGameplayProgress()
        }
        for _ in 0 ..< 300 where store.isRetryingSaveAction {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(attempts == (reset ? 0 : 1))
        #expect(store.roster.gold == (reset ? 0 : 3))
    }
}
