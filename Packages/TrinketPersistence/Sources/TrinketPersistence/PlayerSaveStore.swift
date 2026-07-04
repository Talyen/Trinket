import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private var save: PlayerSave
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )
    public private(set) var lastPersistenceError: PlayerSavePersistenceError?
    public private(set) var loadedFromDisk = false
    public var onLocalSave: ((PlayerSave) -> Void)?

    public var journey: JourneyProgressState {
        get { save.journey }
        set { mutate { $0.journey = PlayerSaveSanitizer.sanitizeJourney(newValue) } }
    }

    public var roster: PlayerRosterState {
        get { resolvedRoster() }
        set { mutate { $0.roster = SavedRosterState(newValue) } }
    }

    public var inventory: PlayerInventoryState {
        get { save.inventory.inventory() }
        set { mutate { $0.inventory = SavedInventoryState(newValue) } }
    }

    public var homestead: PlayerHomesteadState {
        get { save.homestead.homestead() }
        set { mutate { $0.homestead = SavedHomesteadState(newValue) } }
    }

    public var currentSave: PlayerSave {
        save
    }

    public init(fileStore: PlayerSaveFileStore = PlayerSaveFileStore()) {
        self.fileStore = fileStore
        if let loaded = fileStore.load() {
            loadedFromDisk = true
            save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(loaded))
        } else {
            save = PlayerSaveSanitizer.sanitize(.fresh)
        }
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        try mutateThrowing(update)
    }

    public func resetGameplayProgress() throws {
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = save.sessionGeneration &+ 1
        try commitLocalSave(fresh)
    }

    public func applyTestSeed() throws {
        try commitLocalSave(.testSeed)
    }

    public func applyRemoteSave(_ remoteSave: PlayerSave) throws {
        let migrated = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(remoteSave))
        try commitExternalSave(migrated)
        loadedFromDisk = true
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try mutateThrowing(update)
        } catch let error as PlayerSavePersistenceError {
            lastPersistenceError = error
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
        } catch {
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func mutateThrowing(_ update: (inout PlayerSave) -> Void) throws {
        var candidate = save
        update(&candidate)
        candidate = PlayerSaveSanitizer.sanitize(candidate)
        try commitLocalSave(candidate)
    }

    private func commitLocalSave(_ candidate: PlayerSave) throws {
        let persisted = PlayerSaveSanitizer.sanitize(candidate.markedLocalMutation())
        try persistSave(persisted, notifySync: true)
    }

    private func commitExternalSave(_ candidate: PlayerSave) throws {
        let persisted = PlayerSaveSanitizer.sanitize(candidate)
        try persistSave(persisted, notifySync: false)
    }

    private func persistSave(_ persisted: PlayerSave, notifySync: Bool) throws {
        try PlayerSaveSanitizer.validate(persisted)
        var lastError: Error?
        for _ in 1 ... 3 {
            do {
                try fileStore.save(persisted)
                save = persisted
                loadedFromDisk = true
                lastPersistenceError = nil
                if notifySync {
                    onLocalSave?(save)
                }
                return
            } catch let error as PlayerSavePersistenceError {
                lastError = error
            } catch {
                lastError = error
            }
        }
        if let error = lastError as? PlayerSavePersistenceError {
            lastPersistenceError = error
            throw error
        }
        throw lastError ?? PlayerSavePersistenceError.writeFailed
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
