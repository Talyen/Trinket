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
        let didSave = original?.persistFixtureBatch(logging: "Recovery fixture") { save in
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
        _ = original?.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 17 }
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
        _ = original?.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 73 }
        original = nil
        let reset = try context.makeSaveStore(resetState: true)
        #expect(reset.roster.gold == PlayerSave.fresh.roster.gold)
        #expect(!FileManager.default.fileExists(atPath: PendingSaveRecovery.url(for: context.storeURL()).path))
    }

    @Test func `durable reset outranks an older pending save on relaunch`() throws {
        let context = try PersistenceTestContext()
        var original: PlayerSaveStore? = try context.makeSaveStore()
        var account = CloudDeviceState()
        account.activeAccountID = "account"
        try original?.commitCloudState(account)
        #expect(original?.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 42 } == true)
        let priorSave = try #require(original?.currentSave)
        let priorCloudState = try #require(original?.root.cloudStatePayload)

        try original?.resetGameplayProgress()
        let resetGeneration = try #require(original?.currentSave.sessionGeneration)
        #expect(resetGeneration == priorSave.sessionGeneration + 1)
        #expect(original?.cloudDeviceState.account.resetRequested == true)

        // Recreate a sidecar that survived failed post-reset cleanup.
        try original?.pendingSaveRecovery?.write(save: priorSave, cloudState: priorCloudState)
        original = nil
        let restored = try context.makeReloadedStore()
        #expect(restored.roster.gold == PlayerSave.fresh.roster.gold)
        #expect(restored.currentSave.sessionGeneration == resetGeneration)
        #expect(restored.cloudDeviceState.activeAccountID == "account")
        #expect(restored.cloudDeviceState.account.resetRequested)
        #expect(!restored.isPersistenceDegraded)
        #expect(restored.pendingSaveRecovery?.hasPendingSave == false)
    }

    @Test func `failed reset sidecar cleanup retries without reviving old progress`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 42 })
        let priorSave = store.currentSave
        let recovery = try #require(store.pendingSaveRecovery)
        try recovery.write(save: priorSave, cloudState: store.root.cloudStatePayload)
        recovery.forcesNextClearFailure = true
        recovery.forcesNextWriteFailure = true

        try store.resetGameplayProgress()
        #expect(store.roster.gold == PlayerSave.fresh.roster.gold)
        #expect(store.currentSave.sessionGeneration == priorSave.sessionGeneration + 1)
        #expect(store.isPersistenceDegraded)
        #expect(store.lastPersistenceError == .writeFailed)
        #expect(try recovery.read()?.restoredSave().roster.gold == 42)

        for _ in 0 ..< 300 where store.isPersistenceDegraded {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isPersistenceDegraded)
        #expect(store.lastPersistenceError == nil)
        #expect(!recovery.hasPendingSave)
        #expect(try context.makeReloadedStore().roster.gold == PlayerSave.fresh.roster.gold)
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
        _ = original?.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 42 }
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
        #expect(store.persistFixtureBatch(logging: "Recovery fixture") { $0.roster.gold = 47 })
        for _ in 0 ..< 300 where store.isPersistenceDegraded {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isPersistenceDegraded)
        #expect(try context.makeReloadedStore().roster.gold == 47)
    }

    @Test(arguments: [false, true])
    func `awaited transaction stops at validation failure even after a transient failure`(transientFirst: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let before = store.currentSave
        var attempts = 0
        var finished = false
        let pending = Task { () -> PlayerSavePersistenceError? in
            let result = await store.retryingSaveTransaction {
                attempts += 1
                if transientFirst, attempts == 1 {
                    throw PlayerSavePersistenceError.writeFailed
                }
                return store.persistTransaction(logging: "Invalid awaited command fixture") { save -> Result<Void, Never> in
                    save.schemaVersion = 0
                    return .success(())
                }
            }
            if case let .persistFailed(error) = result {
                return error
            }
            return nil
        }
        // A broken retry policy must fail the test instead of retaining it forever.
        let timeout = Task {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(3))
            while !finished, clock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            if !finished {
                pending.cancel()
            }
        }
        defer { timeout.cancel() }
        let result = await pending.value
        finished = true
        guard case .invalidSave = result else {
            Issue.record("Expected a terminal validation failure")
            return
        }
        #expect(attempts == (transientFirst ? 2 : 1))
        #expect(store.currentSave == before)
        #expect(try context.makeReloadedStore().currentSave == before)
    }

    @Test(arguments: [false, true])
    func `pending action retries once and cannot cross reset`(reset: Bool) async throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        var attempts = 0
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return }
            if isRetry {
                attempts += 1
            }
            _ = store.persistFixtureBatch(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        // A second failed submission must not replace the first retained action.
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return }
            if isRetry {
                attempts += 100
            }
            _ = store.persistFixtureBatch(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        if reset {
            try store.resetGameplayProgress()
        }
        for _ in 0 ..< 300 where store.isRetryingSaveAction {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(attempts == (reset ? 0 : 1))
        #expect(store.roster.gold == (reset ? 0 : 3))
    }

    @Test func `obsolete retry preserves an unrelated validation failure`() async throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        var attempts = 0
        store.forcesNextSaveFailure = true
        // The original write fails; its encounter closes before the retry.
        store.performSaveAction(key: "closed-encounter") { [weak store] isRetry in
            if isRetry {
                attempts += 1
                return
            }
            _ = store?.persistFixtureBatch(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        #expect(!store.persistFixtureBatch(logging: "Invalid action fixture") { $0.schemaVersion = 0 })
        let failure = try #require(store.lastPersistenceError)
        guard case .invalidSave = failure else {
            Issue.record("Expected a validation failure")
            return
        }

        for _ in 0 ..< 300 where store.isRetryingSaveAction {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isRetryingSaveAction)
        #expect(attempts == 1)
        #expect(store.lastPersistenceError == failure)
        #expect(store.roster.gold == 0)
    }

    @Test func `nested save action retries only its uncommitted reward`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var openings = 0
        var claims = 0
        store.performSaveAction(key: "open") { [weak store] _ in
            guard let store else { return }
            openings += 1
            #expect(store.persistFixtureBatch(logging: "Opening fixture") { $0.roster.gold += 10 })
            store.forcesNextSaveFailure = true
            store.performSaveAction(key: "reward") { [weak store] _ in
                guard let store else { return }
                claims += 1
                _ = store.persistFixtureBatch(logging: "Reward fixture") { $0.roster.gold += 3 }
            }
        }
        #expect(store.roster.gold == 10)
        #expect(store.isRetryingSaveAction)
        for _ in 0 ..< 300 where store.isRetryingSaveAction {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isRetryingSaveAction)
        #expect(openings == 1)
        #expect(claims == 2)
        #expect(try context.makeReloadedStore().roster.gold == 13)
    }

    @Test(arguments: [false, true])
    func `retry follows command failures when another command succeeds`(invalid: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        var attempts = 0
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return }
            if isRetry {
                attempts += 1
            }
            store.forcesNextSaveFailure = !isRetry || (!invalid && attempts == 1)
            let committed = store.persistFixtureBatch(logging: "Retry fixture") { save in
                if isRetry, invalid {
                    save.schemaVersion = 0
                } else {
                    save.roster.gold += 3
                }
            }
            if !isRetry {
                #expect(!committed)
            }
            // Clearing the shared diagnostic must not conceal a failed reward,
            // including on the initial attempt before registration.
            #expect(store.persistFixtureBatch(logging: "Other command fixture") { $0.corruptionAltarCooldownRemaining = 1 })
        }
        for _ in 0 ..< 300 where store.isRetryingSaveAction {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isRetryingSaveAction)
        #expect(attempts == (invalid ? 1 : 2))
        #expect(store.roster.gold == (invalid ? 0 : 3))
        #expect(try context.makeReloadedStore().roster.gold == (invalid ? 0 : 3))
    }
}
