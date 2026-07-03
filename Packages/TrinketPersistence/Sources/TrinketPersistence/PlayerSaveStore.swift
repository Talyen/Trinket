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
        let loaded = fileStore.load() ?? .fresh
        save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(loaded))
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        try mutateThrowing(update)
    }

    public func resetGameplayProgress() throws {
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = save.sessionGeneration &+ 1
        try commitSave(fresh)
    }

    public func applyTestSeed() throws {
        try commitSave(.testSeed)
    }

    public func applyRemoteSave(_ remoteSave: PlayerSave) throws {
        let migrated = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(remoteSave))
        try commitSave(migrated)
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
        try commitSave(candidate)
    }

    private func commitSave(_ candidate: PlayerSave) throws {
        let persisted = PlayerSaveSanitizer.sanitize(candidate.markedLocalMutation())
        try PlayerSaveSanitizer.validate(persisted)
        try fileStore.save(persisted)
        save = persisted
        lastPersistenceError = nil
        onLocalSave?(save)
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
