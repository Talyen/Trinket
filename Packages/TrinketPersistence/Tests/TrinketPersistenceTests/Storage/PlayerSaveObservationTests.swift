import Observation
import Synchronization
import Testing
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct PlayerSaveObservationTests {
    @Test @MainActor func `wallet commits leave unrelated presentation dependencies quiet and survive reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let before = store.currentSave
        let changed = trackSections(in: store)

        try store.performFixtureMutation { $0.roster.gold += 7 }

        #expect(changed.names.withLock { $0 } == ["roster", "snapshot"])
        var expected = before
        expected.roster.gold += 7
        expected.modifiedAt = store.currentSave.modifiedAt
        #expect(store.currentSave == expected)
        #expect(try context.makeReloadedStore().currentSave == expected)

        // A full replacement must also leave equal sections quiet, while the
        // starter flow still observes generation changes across a reset/import.
        let replacementChanges = trackSections(in: store)
        expected.sessionGeneration += 1
        try store.resetRoot(with: expected)
        #expect(replacementChanges.names.withLock { $0 } == ["generation", "snapshot"])
        #expect(store.currentSave == expected)
        #expect(try context.makeReloadedStore().currentSave == expected)
    }

    #if DEBUG
    @Test @MainActor func `deferred rollback publishes only reverted sections and refused commits publish nothing`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let durable = store.currentSave
        let refusedChanges = trackSections(in: store)
        store.forcesNextSaveFailure = true
        #expect(throws: PlayerSavePersistenceError.self) {
            try store.performFixtureMutation { $0.roster.gold += 7 }
        }
        #expect(refusedChanges.names.withLock { $0 }.isEmpty)
        #expect(store.currentSave == durable)

        try store.performFixtureMutation({ $0.roster.gold += 7 }, persistImmediately: false)
        #expect(refusedChanges.names.withLock { $0 } == ["roster", "snapshot"])
        #expect(store.roster.gold == durable.roster.gold + 7)
        let rollbackChanges = trackSections(in: store)
        store.forcesNextSaveFailure = true
        store.flushPendingPersistence()
        #expect(rollbackChanges.names.withLock { $0 } == ["roster", "snapshot"])
        #expect(store.currentSave == durable)
        #expect(try context.makeReloadedStore().currentSave == durable)
    }
    #endif

    private final class Changes: Sendable {
        let names = Mutex<Set<String>>([])
    }

    @MainActor
    private func trackSections(in store: PlayerSaveStore) -> Changes {
        let changes = Changes()
        let reads: [(String, () -> Void)] = [
            ("journey", { _ = store.journey }),
            ("roster", { _ = store.roster }),
            ("inventory", { _ = store.inventory }),
            ("homestead", { _ = store.homestead }),
            ("spires", { _ = store.spires }),
            ("labyrinth", { _ = store.labyrinth }),
            ("voyage", { _ = store.voyage }),
            ("contracts", { _ = store.contracts }),
            ("starter", { _ = store.starterSelection }),
            ("seed", { _ = store.worldSeed }),
            ("cooldown", { _ = store.corruptionAltarCooldownRemaining }),
            ("generation", { _ = store.sessionGeneration }),
            ("snapshot", { _ = store.currentSave }),
        ]
        for (name, read) in reads {
            withObservationTracking(read) {
                _ = changes.names.withLock { $0.insert(name) }
            }
        }
        return changes
    }
}
