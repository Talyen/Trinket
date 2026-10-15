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
        try store.commitGraph(expected, replacing: store.currentSave, slices: .all, cloudState: store.cloudDeviceState)
        #expect(replacementChanges.names.withLock { $0 } == ["generation", "snapshot"])
        #expect(store.currentSave == expected)
        #expect(try context.makeReloadedStore().currentSave == expected)
    }

    @MainActor private final class PublicationReads {
        var snapshot: PlayerSave?
        var gold: Int?
        var cooldown: Int?
    }

    @Test @MainActor func `cross section reads during publication see one complete committed save`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let before = store.currentSave
        let reads = PublicationReads()
        withObservationTracking {
            _ = store.roster
        } onChange: {
            MainActor.assumeIsolated {
                reads.snapshot = store.currentSave
                reads.gold = store.roster.gold
                reads.cooldown = store.corruptionAltarCooldownRemaining
            }
        }

        try store.performFixtureMutation {
            $0.roster.gold += 7
            $0.corruptionAltarCooldownRemaining = 1
        }

        // Observation's leading edge must see the entire previous commit.
        // Publishing root fields before the roster exposed a torn snapshot here.
        #expect(reads.snapshot == before)
        #expect(reads.gold == before.roster.gold)
        #expect(reads.cooldown == before.corruptionAltarCooldownRemaining)
        let committed = store.currentSave
        #expect(committed.roster.gold == before.roster.gold + 7)
        #expect(committed.corruptionAltarCooldownRemaining == 1)
        #expect(try context.makeReloadedStore().currentSave == committed)
    }

    #if DEBUG
    @Test @MainActor func `refused commits publish nothing and preserve durable progress`() throws {
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
