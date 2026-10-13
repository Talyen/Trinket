import Foundation
import Testing
import TrinketContent
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

    @Test(arguments: [false, true])
    @MainActor func `unencodable item powers reject every graph write before mutation`(reset: Bool) throws {
        let fixture = try PersistenceTestContext()
        let store = try fixture.makeSaveStore()
        try installJournal(in: store)
        let before = store.currentSave
        let metadata = store.root.cloudStatePayload
        let records = try payloads(in: #require(store.cloudOutbox))
        let template = try #require(PlayerSave.testSeed.inventory.items.first)
        var candidate = before
        candidate.roster.gold += 10
        candidate.inventory.items.append(InventoryItem(
            id: "invalid-power", baseType: template.baseType, rarity: template.rarity,
            displayName: template.displayName, affixes: [],
            affixPowers: [ItemAffixPower(description: "Invalid", modifiers: [.goldGainedPercent(.infinity)])],
        ))
        var replacement = store.cloudDeviceState
        replacement.account.journal = nil
        replacement.account.pending = nil

        #expect(throws: PlayerSavePersistenceError.invalidSave("The action could not be saved. Your progress is preserved.")) {
            try store.commitGraph(
                candidate, replacing: before, slices: .all, cloudState: replacement,
                durability: reset ? .primaryOnly : .recoverable,
            )
        }
        #expect(store.currentSave == before)
        #expect(store.root.toPlayerSave() == before)
        #expect(store.root.cloudStatePayload == metadata)
        #expect(try payloads(in: #require(store.cloudOutbox)) == records)
        #expect(store.pendingSaveRecovery?.hasPendingSave == false)
        // A later context save must not leak a rejected partial graph or prune its journal.
        try store.context.save()
        let reloaded = try fixture.makeReloadedStore()
        #expect(reloaded.currentSave == before)
        #expect(reloaded.cloudDeviceState == store.cloudDeviceState)
    }

    @Test @MainActor func `refused graph write restores original opaque item power bytes`() throws {
        let fixture = try PersistenceTestContext()
        let store = try fixture.makeSaveStore()
        let template = try #require(PlayerSave.testSeed.inventory.items.first { !$0.isTrinket && $0.rarity != .unique })
        var initial = store.currentSave
        initial.inventory.items = [InventoryItem(
            id: "preserved-powers", baseType: template.baseType, rarity: template.rarity,
            displayName: template.displayName, affixes: [],
        )]
        try store.commitCloudState(store.cloudDeviceState, replacing: initial)
        let before = store.currentSave
        let item = try #require(store.root.inventory?.items?.first)
        let itemID = item.id
        let opaque = Data("unreadable-item-powers".utf8)
        item.affixPowersJSON = opaque
        var candidate = before
        candidate.inventory.items.removeAll()
        store.forcesNextSaveFailure = true

        #expect(throws: PlayerSavePersistenceError.writeFailed) {
            try store.commitGraph(candidate, replacing: before, slices: .inventory, cloudState: store.cloudDeviceState)
        }
        #expect(store.currentSave == before)
        #expect(store.root.inventory?.items?.first(where: { $0.id == itemID })?.affixPowersJSON == opaque)
        try store.context.save()
        let reloaded = try fixture.makeReloadedStore()
        #expect(reloaded.root.inventory?.items?.first(where: { $0.id == itemID })?.affixPowersJSON == opaque)
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
