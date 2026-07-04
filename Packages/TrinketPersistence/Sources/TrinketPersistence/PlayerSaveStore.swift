import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private let immediatePersistRetryCount: Int
    private let immediatePersistRetryDelayNanoseconds: UInt64
    private var save: PlayerSave
    private var pendingPersistSave: PlayerSave?
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )
    public private(set) var lastPersistenceError: PlayerSavePersistenceError?
    public private(set) var loadedFromDisk = false
    public var onLocalSave: ((PlayerSave) -> Void)?

    public var hasPendingPersist: Bool {
        pendingPersistSave != nil
    }

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

    public init(
        fileStore: PlayerSaveFileStore = PlayerSaveFileStore(),
        immediatePersistRetryCount: Int = 3,
        immediatePersistRetryDelayNanoseconds: UInt64 = 50_000_000
    ) {
        self.fileStore = fileStore
        self.immediatePersistRetryCount = max(1, immediatePersistRetryCount)
        self.immediatePersistRetryDelayNanoseconds = immediatePersistRetryDelayNanoseconds
        if let loaded = fileStore.load() {
            loadedFromDisk = true
            save = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(loaded))
        } else {
            save = PlayerSaveSanitizer.sanitize(.fresh)
        }
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        flushPendingPersistIfNeeded()

        var candidate = save
        update(&candidate)
        candidate = PlayerSaveSanitizer.sanitize(candidate)

        var lastWriteFailure = false
        for attempt in 0 ..< immediatePersistRetryCount {
            if attempt > 0 {
                briefRetryPause(attempt: attempt)
            }
            do {
                try commitSave(candidate, optimisticOnFailure: false)
                return
            } catch let error as PlayerSavePersistenceError {
                switch error {
                case .writeFailed:
                    lastWriteFailure = true
                case .invalidSave:
                    throw error
                }
            }
        }

        if lastWriteFailure {
            try commitSave(candidate, optimisticOnFailure: true)
        }
    }

    public func flushPendingPersistIfNeeded() {
        guard let pending = pendingPersistSave else { return }

        do {
            try fileStore.save(pending)
            save = pending
            pendingPersistSave = nil
            lastPersistenceError = nil
            onLocalSave?(save)
        } catch {
            lastPersistenceError = .writeFailed
            logger.error(
                "Failed to flush pending player save: \(error.localizedDescription, privacy: .public)"
            )
        }
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
        try commitSave(migrated, stampLocalMutation: false, notifyLocalSave: false)
        loadedFromDisk = true
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try mutateThrowing(update)
        } catch let error as PlayerSavePersistenceError {
            if case .invalidSave = error {
                lastPersistenceError = error
                logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func mutateThrowing(_ update: (inout PlayerSave) -> Void) throws {
        flushPendingPersistIfNeeded()

        var candidate = save
        update(&candidate)
        candidate = PlayerSaveSanitizer.sanitize(candidate)
        try commitSave(candidate, optimisticOnFailure: true)
    }

    private func commitSave(
        _ candidate: PlayerSave,
        stampLocalMutation: Bool = true,
        optimisticOnFailure: Bool = false,
        notifyLocalSave: Bool = true
    ) throws {
        var prepared = candidate
        if stampLocalMutation {
            prepared = candidate.markedLocalMutation()
        } else {
            prepared.schemaVersion = PlayerSave.currentSchemaVersion
        }
        let persisted = PlayerSaveSanitizer.sanitize(prepared)
        try PlayerSaveSanitizer.validate(persisted)

        do {
            try fileStore.save(persisted)
            save = persisted
            loadedFromDisk = true
            pendingPersistSave = nil
            lastPersistenceError = nil
            if notifyLocalSave {
                onLocalSave?(save)
            }
        } catch {
            lastPersistenceError = .writeFailed
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
            if optimisticOnFailure {
                save = persisted
                pendingPersistSave = persisted
                if notifyLocalSave {
                    onLocalSave?(save)
                }
            } else {
                throw PlayerSavePersistenceError.writeFailed
            }
        }
    }

    private func briefRetryPause(attempt: Int) {
        guard immediatePersistRetryDelayNanoseconds > 0 else { return }
        let delay = Double(immediatePersistRetryDelayNanoseconds * UInt64(attempt)) / 1_000_000_000
        Thread.sleep(forTimeInterval: delay)
    }

    private func resolvedRoster() -> PlayerRosterState {
        save.playerRoster(inventoryItemIDs: Set(save.inventory.items.map(\.id)))
    }
}
