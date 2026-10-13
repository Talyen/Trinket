import Foundation
import Testing
@testable import TrinketPersistence

struct SaveGraphCommitTests {
    @Test @MainActor func `unencodable metadata cannot prune committed journal rows`() throws {
        let fixture = try PersistenceTestContext()
        let store = try fixture.makeSaveStore()
        try installJournal(in: store)
        let outbox = try #require(store.cloudOutbox)
        let metadata = try #require(store.root.cloudStatePayload)
        let records = payloads(in: outbox)
        var invalid = store.cloudDeviceState
        invalid.account.journal = nil
        invalid.account.pending = nil
        invalid.guestBackup = CloudSaveSnapshot(store.currentSave)
        invalid.guestBackup?.modifiedAt = Date(timeIntervalSinceReferenceDate: .nan)

        #expect(throws: EncodingError.self) { _ = try outbox.stage(invalid) }
        #expect(payloads(in: outbox) == records)
        #expect(try outbox.decode(metadata) == store.cloudDeviceState)
        // Persist the context directly to detect leaked staging mutations even
        // when no subsequent gameplay command reconstructs the old journal.
        try store.context.save()
        let reloaded = try fixture.makeReloadedStore()
        #expect(!reloaded.preservesUnreadableCloudState)
        #expect(reloaded.cloudDeviceState == store.cloudDeviceState)
        #expect(reloaded.roster.gold == 7)
    }

    @Test(arguments: [false, true])
    @MainActor func `refused replacements preserve pruned journal and pending request across reload`(reset: Bool) throws {
        let fixture = try PersistenceTestContext()
        let store = try fixture.makeSaveStore()
        try installJournal(in: store)
        let save = store.currentSave
        let state = store.cloudDeviceState
        let metadata = store.root.cloudStatePayload
        let records = try payloads(in: #require(store.cloudOutbox))
        var invalidations = 0
        store.onExternalProgressChange = { invalidations += 1 }
        store.forcesNextSaveFailure = true

        #expect(throws: PlayerSavePersistenceError.writeFailed) {
            if reset {
                try store.resetGameplayProgress()
            } else {
                var replacement = CloudDeviceState()
                replacement.activeAccountID = "other-account"
                try store.commitCloudState(replacement, replacing: .fresh)
            }
        }
        #expect(store.currentSave == save)
        #expect(store.cloudDeviceState == state)
        #expect(store.root.cloudStatePayload == metadata)
        #expect(try payloads(in: #require(store.cloudOutbox)) == records)
        #expect(invalidations == 0)
        #expect(store.persistFixtureBatch(logging: "Post-compensation save") { $0.roster.gold += 2 })

        let reloaded = try fixture.makeReloadedStore()
        #expect(reloaded.roster.gold == 9)
        #expect(reloaded.sessionGeneration == save.sessionGeneration)
        #expect(reloaded.cloudDeviceState == state)
        #expect(try payloads(in: #require(reloaded.cloudOutbox)) == records)
    }

    @Test @MainActor func `degraded reset refuses database failure without replacing recoverable progress`() throws {
        let fixture = try PersistenceTestContext()
        try Data("unreadable database".utf8).write(to: fixture.storeURL())
        var saved = PlayerSave.fresh
        saved.roster.gold = 42
        var state = CloudDeviceState()
        state.activeAccountID = "account"
        let recovery = PendingSaveRecovery(storeURL: fixture.storeURL())
        try recovery.write(save: saved, cloudState: JSONEncoder().encode(state))
        let store = try fixture.makeSaveStore()
        #expect(store.usesMemoryFallback)
        let before = store.currentSave
        store.forcesNextDatabaseSaveFailure = true

        #expect(throws: PlayerSavePersistenceError.writeFailed) { try store.resetGameplayProgress() }
        #expect(store.currentSave == before)
        #expect(store.cloudDeviceState == state)
        #expect(store.usesMemoryFallback)
        #expect(try recovery.read()?.restoredSave().roster.gold == 42)
        #expect(try fixture.makeReloadedStore().roster.gold == 42)
    }

    @MainActor private func installJournal(in store: PlayerSaveStore) throws {
        let before = store.currentSave
        var after = before
        after.roster.gold = 7
        var state = store.cloudDeviceState
        state.activeAccountID = "account"
        state.account.journal = CloudSaveJournal([CloudSaveMutation(
            id: "earned-gold", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(after),
        )])
        let (pending, _) = CloudSaveTransitions.enqueue(
            .upload, state: state, local: CloudSaveSnapshot(after), id: "pending-upload",
        )
        try store.commitCloudState(pending, replacing: after)
    }

    @MainActor private func payloads(in outbox: CloudSaveOutbox) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: outbox.storedRecords.map { ("\($0.journalID):\($0.index)", $0.payload) })
    }
}
