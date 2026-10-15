import Observation
import Testing
@testable import TrinketPersistence

@MainActor
struct SaveTransactionRevisionTests {
    @Test(arguments: [false, true])
    func `outer candidate cannot overwrite a nested durable command`(recordsReceipts: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let mutate: (inout PlayerSave) -> Result<Void, Never> = { save in
            save.corruptionAltarCooldownRemaining = 1
            #expect(store.persistBatch(logging: "Nested command") { $0.corruptionAltarCooldownRemaining = 3 })
            return .success(())
        }
        let result: SaveTransactionResult<Void, Never> = if recordsReceipts {
            store.persistTransaction(logging: "Outer command") { save, _ in mutate(&save) }
        } else {
            store.persistTransaction(logging: "Outer command", mutate)
        }
        guard case .persistFailed(.invalidSave) = result else {
            Issue.record("Expected rejection of an obsolete save candidate")
            return
        }
        #expect(store.corruptionAltarCooldownRemaining == 3)
        #expect(try context.makeReloadedStore().corruptionAltarCooldownRemaining == 3)
    }

    #if DEBUG
    enum PublicationWrite: CaseIterable, Sendable {
        case gameplay, reset, cloud

        @MainActor func perform(in store: PlayerSaveStore) throws {
            switch self {
            case .gameplay:
                try store.performBatchMutation { $0.roster.unlockHero(id: "wizard") }
            case .reset:
                try store.resetGameplayProgress()
            case .cloud:
                try store.commitCloudState(store.cloudDeviceState, replacing: .fresh)
            }
        }
    }

    @MainActor private final class PublicationAttempt {
        var called = false
        var failure: PlayerSavePersistenceError?
        var candidate: SaveEconomicMutation?
    }

    @Test(arguments: PublicationWrite.allCases)
    func `publication cannot reenter gameplay reset or cloud commits`(write: PublicationWrite) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let before = store.currentSave
        let attempt = PublicationAttempt()
        withObservationTracking {
            _ = store.roster
        } onChange: {
            MainActor.assumeIsolated {
                attempt.called = true
                do {
                    try write.perform(in: store)
                    Issue.record("A write entered an unfinished save publication")
                } catch {
                    attempt.failure = PlayerSavePersistenceError.mapped(error)
                }
            }
        }

        try store.performFixtureMutation {
            $0.roster.gold += 7
            $0.corruptionAltarCooldownRemaining = 1
        }

        #expect(attempt.called)
        #expect(attempt.failure?.isRetryable == true)
        var expected = before
        expected.roster.gold += 7
        expected.corruptionAltarCooldownRemaining = 1
        expected.modifiedAt = store.currentSave.modifiedAt
        #expect(store.currentSave == expected)
        #expect(try context.makeReloadedStore().currentSave == expected)

        // Admission reopens after publication; a fresh attempt keeps the reward.
        try store.performBatchMutation { $0.corruptionAltarCooldownRemaining = 3 }
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == expected.roster.gold)
        #expect(reloaded.corruptionAltarCooldownRemaining == 3)
    }

    @Test func `candidate captured during publication cannot erase a recruited hero`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let attempt = PublicationAttempt()
        withObservationTracking {
            _ = store.roster
        } onChange: {
            MainActor.assumeIsolated {
                attempt.candidate = store.makeMutation()
                attempt.candidate?.save.corruptionAltarCooldownRemaining = 3
            }
        }

        try store.performBatchMutation { $0.roster.unlockHero(id: "knight") }
        let committed = store.currentSave
        #expect(committed.roster.unlockedHeroIDs.contains("knight"))
        let candidate = try #require(attempt.candidate)
        do {
            try store.commit(candidate)
            Issue.record("A partial publication snapshot erased a recruited hero")
        } catch {
            guard case .invalidSave = PlayerSavePersistenceError.mapped(error) else {
                Issue.record("Expected rejection of an obsolete publication snapshot")
                return
            }
        }
        #expect(store.currentSave == committed)
        #expect(try context.makeReloadedStore().currentSave == committed)
    }
    #endif
}
