import Foundation
import SwiftData
import Testing
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveJournalTests {
    @Test func `legacy action pairs retain rewards selections and deferred gaps`() throws {
        let initial = CloudSaveSnapshot(PlayerSave.fresh)
        var earned = initial
        earned.roster.gold += 7
        var gap = CloudSaveSnapshot(PlayerSave.unlockedAll)
        gap.worldSeed = .max
        gap.voyagePayload = Data([0, 255])
        var cleared = gap
        cleared.voyagePayload = nil
        cleared.inventory = []
        cleared.corruptionAltarCooldownRemaining = 3
        let mutations = [
            CloudSaveMutation(id: "legacy", changedSliceMask: PlayerSaveSlice.all.rawValue, before: initial, after: earned),
            CloudSaveMutation(id: "after-deferred-edit", changedSliceMask: PlayerSaveSlice.all.rawValue, before: gap, after: cleared),
        ]
        let oldData = try JSONEncoder().encode(mutations)
        let migrated = try JSONDecoder().decode(CloudSaveJournal.self, from: oldData)
        #expect(Array(migrated) == mutations)
        let compactData = try JSONEncoder().encode(migrated)
        let reloaded = try JSONDecoder().decode(CloudSaveJournal.self, from: compactData)
        #expect(Array(reloaded) == mutations)
        #expect(reloaded == migrated)
        #expect(reloaded.lastSnapshot == cleared)
    }

    @Test @MainActor func `thousands of offline actions append small records without rewriting history`() throws {
        let fixture = try PersistenceTestContext()
        let store = try fixture.makeInMemoryStore()
        let outbox = try #require(store.cloudOutbox)
        var state = CloudDeviceState()
        state.activeAccountID = "offline-player"
        var snapshot = CloudSaveSnapshot(PlayerSave.unlockedAll)
        snapshot.roster.gold = 0
        snapshot.modifiedAt = Date(timeIntervalSince1970: 2000000000)
        let fullSnapshotBytes = try JSONEncoder().encode(snapshot).count
        var journal = CloudSaveJournal()
        var earlyMetadataBytes = 0
        var checkpointPayload: Data?
        for index in 0 ..< 4096 {
            var next = snapshot
            next.roster.gold += 1
            next.modifiedAt = snapshot.modifiedAt.addingTimeInterval(1)
            journal.append(CloudSaveMutation(
                id: "reward-\(index)", changedSliceMask: PlayerSaveSlice.roster.rawValue,
                before: snapshot, after: next,
            ))
            state.account.journal = journal
            let metadata = try outbox.stage(state)
            if index == 63 {
                earlyMetadataBytes = metadata.count
                checkpointPayload = outbox.storedRecords.first { $0.index == -1 }?.payload
            }
            if index == 4095 {
                #expect(metadata.count <= earlyMetadataBytes + 16)
                let reloaded = try outbox.decode(metadata)
                #expect(reloaded.account.journal?.lastSnapshot == next)
                #expect(reloaded.account.journal?.records.map(\.id) == journal.records.map(\.id))
            }
            snapshot = next
        }
        let rows = outbox.storedRecords
        #expect(rows.count == 4097)
        #expect(rows.first { $0.index == -1 }?.payload == checkpointPayload)
        let compactBytes = rows.reduce(0) { $0 + $1.payload.count }
        let oldSnapshotBytes = 4096 * 2 * fullSnapshotBytes
        #expect(compactBytes < oldSnapshotBytes / 10)
        try store.context.save()
        _ = try outbox.stage(state)
        #expect(!store.context.hasChanges)
    }
}
