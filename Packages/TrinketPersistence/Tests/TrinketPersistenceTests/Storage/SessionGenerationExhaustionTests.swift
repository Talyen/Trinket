import Foundation
import Testing
@testable import TrinketPersistence

struct SessionGenerationExhaustionTests {
    private let exhausted = PlayerSavePersistenceError.invalidSave(
        "The saved session generation is exhausted. Your progress is preserved.",
    )

    @Test(arguments: [false, true]) @MainActor
    func `an exhausted reset preserves durable and fallback progress before cleanup`(fallback: Bool) throws {
        let context = try PersistenceTestContext()
        let original = Data("unreadable-player-store".utf8)
        if fallback {
            try original.write(to: context.storeURL())
        }
        let store = try context.makeReloadedStore()
        #expect(store.usesMemoryFallback == fallback)
        try store.performFixtureMutation { save in
            save.sessionGeneration = .max
            save.roster.gold = 42
        }
        var metadata = store.cloudDeviceState
        metadata.counter = 17
        metadata.activeAccountID = "exhausted-session-account"
        try store.commitCloudState(metadata)
        let before = store.currentSave
        let pendingURL = PendingSaveRecovery.url(for: context.storeURL())
        let pending = fallback ? try Data(contentsOf: pendingURL) : nil

        #expect(!exhausted.isRetryable)
        #expect(throws: exhausted) { try store.resetGameplayProgress() }
        #expect(store.currentSave == before)
        #expect(store.cloudDeviceState == metadata)
        if fallback {
            #expect(try Data(contentsOf: context.storeURL()) == original)
            #expect(try Data(contentsOf: pendingURL) == pending)
        }
        let restored = try context.makeReloadedStore()
        #expect(restored.currentSave == before)
        #expect(restored.cloudDeviceState == metadata)
        #expect(restored.usesMemoryFallback == fallback)
    }

    @Test @MainActor func `exhausted external replacement rejects without publishing or saving metadata`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeReloadedStore()
        try store.performFixtureMutation { $0.sessionGeneration = .max }
        let before = store.currentSave
        let beforeMetadata = store.cloudDeviceState
        var incoming = before
        incoming.roster.gold = 42
        var metadata = beforeMetadata
        metadata.counter = 17
        var invalidated = false
        store.onExternalProgressChange = { invalidated = true }

        #expect(throws: exhausted) { try store.commitCloudState(metadata, replacing: incoming) }
        #expect(store.currentSave == before)
        #expect(store.cloudDeviceState == beforeMetadata)
        #expect(!invalidated)
        let restored = try context.makeReloadedStore()
        #expect(restored.currentSave == before)
        #expect(restored.cloudDeviceState == beforeMetadata)

        try store.commitCloudState(metadata)
        #expect(store.currentSave.sessionGeneration == .max)
        #expect(store.cloudDeviceState == metadata)
        try store.commitCloudState(metadata, replacing: incoming, invalidatesSession: false)
        #expect(store.roster.gold == 42)
        #expect(store.currentSave.sessionGeneration == .max)
        #expect(!invalidated)
        let accepted = try context.makeReloadedStore()
        #expect(accepted.roster.gold == 42)
        #expect(accepted.currentSave.sessionGeneration == .max)
        #expect(accepted.cloudDeviceState == metadata)
    }

    @Test(arguments: [false, true]) @MainActor
    func `the final unused session generation is accepted and survives reload`(cloudReplacement: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeReloadedStore()
        try store.performFixtureMutation { $0.sessionGeneration = UInt64.max - 1 }
        if cloudReplacement {
            var incoming = store.currentSave
            incoming.roster.gold = 42
            try store.commitCloudState(store.cloudDeviceState, replacing: incoming)
            #expect(store.roster.gold == 42)
        } else {
            try store.applyTestSeed()
        }
        #expect(store.currentSave.sessionGeneration == .max)
        #expect(try context.makeReloadedStore().currentSave == store.currentSave)
    }
}
