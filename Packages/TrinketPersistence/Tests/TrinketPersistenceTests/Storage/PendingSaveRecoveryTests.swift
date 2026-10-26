import Foundation
import SwiftData
import Testing
import TrinketContent
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

        try await waitUntilSettled(store, \.isPersistenceDegraded)
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
        try await waitUntilSettled(store, \.isPersistenceDegraded)
        #expect(!store.isPersistenceDegraded)
        #expect(try context.makeReloadedStore().roster.gold == 47)
    }

    @Test func `cancellation during a committed transaction preserves the reported outcome and durable reward`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let initialGold = store.roster.gold
        let pending = Task {
            await store.retryingSaveTransaction {
                let result: SaveTransactionResult<Int, Never> = store.persistAction(logging: "Cancellation fixture") { save in
                    let granted = save.grantGold(7)
                    return .success(granted)
                }
                withUnsafeCurrentTask { $0?.cancel() }
                return result
            }
        }
        guard case let .committed(granted) = await pending.value else {
            Issue.record("A committed reward must remain successful when its task is cancelled")
            return
        }
        #expect(granted == 7)
        #expect(store.roster.gold == initialGold + 7)
        #expect(try context.makeReloadedStore().roster.gold == initialGold + 7)
    }

    @Test(arguments: [false, true])
    func `awaited transaction stops at validation failure even after a transient failure`(transientFirst: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let before = store.currentSave
        var attempts = 0
        let expectedAttempts = transientFirst ? 2 : 1
        let pending = Task { () -> PlayerSavePersistenceError? in
            let result = await store.retryingSaveTransaction {
                attempts += 1
                // Bound a broken retry policy without timing shared-actor scheduling.
                if attempts > expectedAttempts {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
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
        let result = await pending.value
        #expect(attempts == expectedAttempts)
        guard case .invalidSave = result else {
            Issue.record("Expected a terminal validation failure; got \(String(describing: result))")
            return
        }
        #expect(store.currentSave == before)
        #expect(try context.makeReloadedStore().currentSave == before)
    }

    @Test(arguments: [false, true])
    func `latest pending action retries once and cannot cross reset`(reset: Bool) async throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        var attempts = 0
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return SaveActionAttempt(false) }
            if isRetry {
                attempts += 1
            }
            return store.persistFixtureAction(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        // A newer failed submission owns the retry; reset still cancels it.
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return SaveActionAttempt(false) }
            if isRetry {
                attempts += 100
            }
            return store.persistFixtureAction(logging: "Retry fixture") { $0.roster.gold += 3 }
        }
        if reset {
            try store.resetGameplayProgress()
        }
        try await waitUntilSettled(store, \.isRetryingSaveAction)
        #expect(attempts == (reset ? 0 : 100))
        #expect(store.roster.gold == (reset ? 0 : 3))
    }

    @Test(arguments: [false, true])
    func `new party choice supersedes a failed selection even without a write`(alreadySelected: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        store.contentAccess = .fullGame
        let knight = try #require(GameContent.hero(matching: "knight"))
        let druid = try #require(GameContent.hero(matching: "druid"))
        try store.performFixtureMutation { save in
            _ = save.roster.unlock(knight)
            _ = save.roster.unlock(druid)
        }
        let latestID = alreadySelected ? store.roster.activeHeroID : druid.id
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "party-Hero") { [weak store] _ in
            store?.selectParty(heroID: knight.id) ?? SaveActionAttempt(.unavailable)
        }
        #expect(store.isRetryingSaveAction)
        store.performSaveAction(key: "party-Hero") { [weak store] _ in
            guard let store, store.roster.activeHeroID != latestID else { return SaveActionAttempt(RosterEditResult.unavailable) }
            let result = store.selectParty(heroID: latestID)
            #expect(result.value == .committed)
            return result
        }
        #expect(!store.isRetryingSaveAction)
        try await waitUntilSettled(store, \.isRetryingSaveAction)
        #expect(store.roster.activeHeroID == latestID)
        #expect(try context.makeReloadedStore().roster.activeHeroID == latestID)
    }

    @Test func `retry callback cannot discard its replacement action`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        store.forcesNextSaveFailure = true
        store.performSaveAction(key: "claim") { [weak store] isRetry in
            guard let store else { return SaveActionAttempt(false) }
            if !isRetry {
                return store.persistFixtureAction(logging: "Original fixture") { $0.roster.gold += 3 }
            }
            store.forcesNextSaveFailure = true
            store.performSaveAction(key: "claim") { [weak store] _ in
                store?.persistFixtureAction(logging: "Replacement fixture") { $0.roster.gold += 7 } ?? SaveActionAttempt(false)
            }
            return SaveActionAttempt(true)
        }
        try await waitUntilSettled(store, \.isRetryingSaveAction)
        #expect(!store.isRetryingSaveAction)
        #expect(try context.makeReloadedStore().roster.gold == 7)
    }

    @Test func `obsolete retry preserves an unrelated validation failure`() async throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        var attempts = 0
        store.forcesNextSaveFailure = true
        // The original write fails; its encounter closes before the retry.
        store.performSaveAction(key: "closed-encounter") { [weak store] isRetry in
            if isRetry {
                attempts += 1
                return SaveActionAttempt(false)
            }
            return store?.persistFixtureAction(logging: "Retry fixture") { $0.roster.gold += 3 } ?? SaveActionAttempt(false)
        }
        #expect(!store.persistFixtureBatch(logging: "Invalid action fixture") { $0.schemaVersion = 0 })
        let failure = try #require(store.lastPersistenceError)
        guard case .invalidSave = failure else {
            Issue.record("Expected a validation failure")
            return
        }

        try await waitUntilSettled(store, \.isRetryingSaveAction)
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
            guard let store else { return SaveActionAttempt(false) }
            openings += 1
            let opening = store.persistFixtureAction(logging: "Opening fixture") { $0.roster.gold += 10 }
            #expect(opening.value)
            store.forcesNextSaveFailure = true
            store.performSaveAction(key: "reward") { [weak store] _ in
                guard let store else { return SaveActionAttempt(false) }
                claims += 1
                return store.persistFixtureAction(logging: "Reward fixture") { $0.roster.gold += 3 }
            }
            return opening
        }
        #expect(store.roster.gold == 10)
        #expect(store.isRetryingSaveAction)
        try await waitUntilSettled(store, \.isRetryingSaveAction)
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
            guard let store else { return SaveActionAttempt(false) }
            if isRetry {
                attempts += 1
            }
            store.forcesNextSaveFailure = !isRetry || (!invalid && attempts == 1)
            let committed = store.persistFixtureAction(logging: "Retry fixture") { save in
                if isRetry, invalid {
                    save.schemaVersion = 0
                } else {
                    save.roster.gold += 3
                }
            }
            if !isRetry {
                #expect(!committed.value)
            }
            // Clearing the shared diagnostic must not conceal a failed reward,
            // including on the initial attempt before registration.
            #expect(store.persistFixtureBatch(logging: "Other command fixture") { $0.corruptionAltarCooldownRemaining = 1 })
            return committed
        }
        try await waitUntilSettled(store, \.isRetryingSaveAction)
        #expect(!store.isRetryingSaveAction)
        #expect(attempts == (invalid ? 1 : 2))
        #expect(store.roster.gold == (invalid ? 0 : 3))
        #expect(try context.makeReloadedStore().roster.gold == (invalid ? 0 : 3))
    }
}

extension PendingSaveRecoveryTests {
    @Test(arguments: ["malformed", "envelope-version", "snapshot-version", "previous-write", "read"])
    func `failed recovery refuses an older writable save and preserves the pending record`(failure: String) throws {
        let fixture = try PersistenceTestContext()
        var original: PlayerSaveStore? = try fixture.makeSaveStore()
        #expect(original?.persistFixtureBatch(logging: "Primary fixture") { $0.roster.gold = 17 } == true)
        var recovered = try #require(original?.currentSave)
        recovered.roster.gold = 73
        let recovery = try #require(original?.pendingSaveRecovery)
        try recovery.write(
            save: recovered, cloudState: original?.root.cloudStatePayload,
            outboxRecords: original?.cloudOutbox?.storedRecords,
        )
        original = nil
        let validData = try Data(contentsOf: recovery.url)
        switch failure {
        case "malformed":
            try Data("unreadable recovery".utf8).write(to: recovery.url)
        case "envelope-version", "snapshot-version":
            var payload = try #require(JSONSerialization.jsonObject(with: validData) as? [String: Any])
            if failure == "envelope-version" {
                payload["version"] = 999
            } else {
                var snapshot = try #require(payload["snapshot"] as? [String: Any])
                snapshot["schemaVersion"] = 999
                payload["snapshot"] = snapshot
            }
            try JSONSerialization.data(withJSONObject: payload).write(to: recovery.url)
        case "previous-write":
            // Restoration must also refuse when archiving the older graph fails.
            try FileManager.default.createDirectory(at: recovery.previousFileURL, withIntermediateDirectories: false)
        case "read":
            try FileManager.default.removeItem(at: recovery.url)
            try FileManager.default.createDirectory(at: recovery.url, withIntermediateDirectories: false)
            try validData.write(to: recovery.url.appending(path: "preserved"))
        default:
            Issue.record("Unknown failure fixture")
            return
        }
        let preservedURL = failure == "read" ? recovery.url.appending(path: "preserved") : recovery.url
        let preservedData = try Data(contentsOf: preservedURL)

        #expect(throws: PlayerSavePersistenceError.self) { _ = try fixture.makeReloadedStore() }
        #expect(try Data(contentsOf: preservedURL) == preservedData)
        do {
            let sideContext = try fixture.makeSideContext()
            let primary = try #require(try sideContext.fetch(FetchDescriptor<PlayerSaveRoot>()).first)
            #expect(primary.toPlayerSave().roster.gold == 17)
        }

        if failure == "previous-write" {
            try FileManager.default.removeItem(at: recovery.previousFileURL)
        } else if failure == "read" {
            try FileManager.default.removeItem(at: recovery.url)
        }
        try validData.write(to: recovery.url)
        let restored = try fixture.makeReloadedStore()
        #expect(restored.currentSave == recovered)
        #expect(!restored.isPersistenceDegraded)
        #expect(try fixture.makeReloadedStore().currentSave == recovered)
    }

    @Test func `accepted recovery write cannot become a refused action after database failure`() throws {
        let fixture = try PersistenceTestContext()
        var original: PlayerSaveStore? = try fixture.makeSaveStore()
        let recovery = try #require(original?.pendingSaveRecovery)
        let metadata = original?.root.cloudStatePayload
        let records = original?.cloudOutbox?.storedRecords
        var candidate = try #require(original?.currentSave)
        candidate.roster.gold = 17
        try recovery.write(save: candidate, cloudState: metadata, outboxRecords: records)
        candidate.roster.gold = 29

        let needsRetry = try recovery.persist(
            save: candidate, cloudState: metadata, memoryFallback: false, outboxRecords: { records },
            primaryWrite: {
                // The candidate's sidecar is already durable. A subsequent disk
                // failure must not make the store compensate or retry its action.
                recovery.forcesNextWriteFailure = true
                throw PlayerSavePersistenceError.writeFailed
            },
        )
        #expect(needsRetry)
        #expect(try recovery.read()?.restoredSave() == candidate)
        original = nil
        let restored = try fixture.makeReloadedStore()
        #expect(restored.currentSave == candidate)
        #expect(!restored.isPersistenceDegraded)
    }

    @Test func `refused recovery prewrite cannot accept an older pending candidate`() throws {
        let fixture = try PersistenceTestContext()
        let recovery = PendingSaveRecovery(storeURL: fixture.storeURL())
        var previous = try fixture.makeSaveStore().currentSave
        previous.roster.gold = 17
        try recovery.write(save: previous, cloudState: nil)
        var candidate = previous
        candidate.roster.gold = 29
        recovery.forcesNextWriteFailure = true
        var primaryWasCalled = false

        #expect(throws: PlayerSavePersistenceError.writeFailed) {
            _ = try recovery.persist(save: candidate, cloudState: nil, memoryFallback: false) {
                primaryWasCalled = true
            }
        }
        #expect(!primaryWasCalled)
        #expect(try fixture.makeReloadedStore().currentSave == previous)
    }

    @Test func `database failure with unreadable map keeps other progress across relaunch`() throws {
        let fixture = try PersistenceTestContext()
        var original: PlayerSaveStore? = try fixture.makeSaveStore()
        let opaque = Data("unreadable-labyrinth-map".utf8)
        // An unrelated slice can save while an unreadable graph awaits repair.
        let map = try #require(original?.root.labyrinth)
        map.worldSeed = try #require(original?.worldSeed)
        map.hasEntered = true
        map.mapPayload = opaque
        original?.forcesNextDatabaseSaveFailure = true
        #expect(original?.persistFixtureBatch(logging: "Recovery with unreadable map") {
            $0.roster.gold = 73
            $0.roster.progressions[$0.roster.activeHeroID] = .at(level: 4)
        } == true)
        let record = try #require(try original?.pendingSaveRecovery?.read())
        #expect(record.unreadableLabyrinthPayload == opaque)
        #expect(try record.restoredSave().roster.gold == 73)
        // Keep cloud admission strict; local recovery is a separate boundary.
        #expect(throws: CloudSaveError.unsupportedSave) { _ = try record.snapshot.restored() }
        original = nil

        let restored = try fixture.makeReloadedStore()
        #expect(restored.roster.gold == 73)
        #expect(restored.roster.progressions[restored.roster.activeHeroID]?.level == 4)
        #expect(restored.labyrinth.hasMap)
        #expect(!restored.labyrinth.isMapPayloadUnreadable)
        #expect(!restored.isPersistenceDegraded)
        #expect(try fixture.makeReloadedStore().currentSave == restored.currentSave)
    }

    @Test func `local recovery preserves opaque map in a replacement graph and reads older sidecars`() throws {
        let fixture = try PersistenceTestContext()
        var save = PlayerSave.fresh
        save.roster.gold = 42
        save.labyrinth = PlayerLabyrinthState(worldSeed: save.worldSeed, hasEntered: true, isMapPayloadUnreadable: true)
        let opaque = Data("preserved-map".utf8)
        let recovery = PendingSaveRecovery(storeURL: fixture.storeURL())
        try recovery.write(save: save, cloudState: nil, labyrinthPayload: opaque)
        let replacement = try fixture.makeInMemoryStore()
        try recovery.restore(into: replacement.root, context: replacement.context, preservesPrevious: false)
        #expect(replacement.root.labyrinth?.mapPayload == opaque)
        #expect(replacement.root.toPlayerSave().roster.gold == 42)

        // Version-one records without the additive opaque field remain readable.
        var legacy = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: recovery.url)) as? [String: Any])
        legacy.removeValue(forKey: "unreadableLabyrinthPayload")
        try JSONSerialization.data(withJSONObject: legacy).write(to: recovery.url)
        let restored = try fixture.makeReloadedStore()
        #expect(restored.roster.gold == 42)
        #expect(restored.labyrinth.hasMap)
        #expect(try fixture.makeReloadedStore().roster.gold == 42)
    }
}

private extension PendingSaveRecoveryTests {
    /// Single knob for background-retry settling: one timing constant instead
    /// of one polling loop per test.
    func waitUntilSettled(_ store: PlayerSaveStore, _ pending: KeyPath<PlayerSaveStore, Bool>) async throws {
        for _ in 0 ..< 300 where store[keyPath: pending] {
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}
