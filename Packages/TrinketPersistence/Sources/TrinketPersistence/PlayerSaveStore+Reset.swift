import Foundation
import SwiftData

@MainActor
public extension PlayerSaveStore {
    func resetGameplayProgress() throws {
        // Degraded-store replacement mutates storage before entering commitGraph.
        try requireCommitAdmission()
        var state = cloudDeviceState
        if state.activeAccountID != nil {
            state.account.pending = nil
            state.account.resetRequested = true
            state.account.journal = nil
        }
        if usesMemoryFallback {
            try resetDurableStorage(cloudState: state)
        } else {
            try resetWithIncrementedSessionGeneration(.fresh, cloudState: state)
        }
    }

    func applyTestSeed() throws {
        try resetWithIncrementedSessionGeneration(.testSeed)
    }

    func unlockAllContent() throws {
        try resetWithIncrementedSessionGeneration(.unlockedAll)
    }

    private func resetDurableStorage(cloudState: CloudDeviceState) throws {
        guard let recoveryConfiguration else {
            throw PlayerSavePersistenceError.storeUnavailable(
                "Couldn't reset saved progress on this device.",
            )
        }
        // Reserve a fresh identity before any destructive recovery work.
        let generation = try nextSessionGeneration()
        let previous = (container: container, context: context, root: root, outbox: cloudOutbox)
        do {
            try PlayerSaveStoreConfiguration.cleanStoreFiles(
                at: recoveryConfiguration.url,
                includingRecovery: false,
            )
            let replacement = try ModelContainer(for: PlayerSaveGraph.schema, configurations: recoveryConfiguration)
            let replacementContext = ModelContext(replacement)
            replacementContext.autosaveEnabled = false
            try replacementContext.delete(model: PlayerSaveRoot.self)
            var save = PlayerSaveSanitizer.sanitize(.fresh)
            save.sessionGeneration = generation
            let replacementRoot = try PlayerSaveRoot(save: save)
            replacementContext.insert(replacementRoot)
            container = replacement
            context = replacementContext
            root = replacementRoot
            cloudOutbox = try CloudSaveOutbox(context: replacementContext)
            usesMemoryFallback = false
            try commitGraph(save, replacing: currentSave, slices: .all, cloudState: cloudState, durability: .primaryOnly)
            // Recompute cloud enablement now that durable storage is back;
            // init disables cloud on memory fallback, so re-enable when a
            // cloud transport was requested.
            if cloudSyncRequested {
                enableCloudAfterDurableRecovery(
                    transport: CloudKitSaveTransport(containerIdentifier: Self.cloudKitContainerIdentifier),
                )
            }
        } catch {
            container = previous.container
            context = previous.context
            root = previous.root
            cloudOutbox = previous.outbox
            usesMemoryFallback = true
            isPersistenceDegraded = true
            let mapped = PlayerSavePersistenceError.mapped(error)
            notePersistenceFailure(mapped, logging: "Failed to restore durable player storage")
            throw mapped
        }
    }

    private func resetWithIncrementedSessionGeneration(_ base: PlayerSave, cloudState: CloudDeviceState? = nil) throws {
        var save = base
        save.sessionGeneration = try nextSessionGeneration()
        let sanitized = try PlayerSaveSanitizer.sanitizeAndValidate(save)
        try commitGraph(
            sanitized, replacing: currentSave, slices: .all,
            cloudState: cloudState ?? cloudDeviceState, durability: .primaryOnly,
        )
    }
}

@MainActor
extension PlayerSaveStore {
    func nextSessionGeneration() throws -> UInt64 {
        let (generation, overflow) = currentSave.sessionGeneration.addingReportingOverflow(1)
        guard !overflow else {
            throw PlayerSavePersistenceError.invalidSave("The saved session generation is exhausted. Your progress is preserved.")
        }
        return generation
    }
}
