import Foundation
import Observation
import os

@MainActor
@Observable
public final class PlayerSaveStore {
    private let fileStore: PlayerSaveFileStore
    private let immediatePersistRetryCount: Int
    private let immediatePersistRetryDelayNanoseconds: UInt64
    private let persistDebounceNanoseconds: UInt64
    private var save: PlayerSave
    private var pendingPersistSave: PlayerSave?
    private var debouncedPersistSave: PlayerSave?
    private var debouncedPersistTask: Task<Void, Never>?
    private var isPersisting = false
    private var cachedRoster: PlayerRosterState?
    private var cachedRosterSnapshot: SavedRosterState?
    private var cachedRosterInventoryIDs: Set<String>?
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )
    public private(set) var lastPersistenceError: PlayerSavePersistenceError?
    public private(set) var loadedFromDisk = false
    public private(set) var hadCorruptSaveOnLoad = false
    public private(set) var hadUnsupportedNewerSaveOnLoad = false
    public var onLocalSave: ((PlayerSave) -> Void)?
    package var testSaveBarrier: (() -> Void)?

    public var hasPendingPersist: Bool {
        pendingPersistSave != nil || debouncedPersistSave != nil
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
        immediatePersistRetryDelayNanoseconds: UInt64 = 50_000_000,
        persistDebounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.fileStore = fileStore
        self.immediatePersistRetryCount = max(1, immediatePersistRetryCount)
        self.immediatePersistRetryDelayNanoseconds = immediatePersistRetryDelayNanoseconds
        self.persistDebounceNanoseconds = persistDebounceNanoseconds
        switch fileStore.loadOutcome() {
        case let .loaded(loaded):
            loadedFromDisk = true
            save = loaded
        case .corrupt:
            hadCorruptSaveOnLoad = true
            fileStore.quarantineCorruptSaves()
            save = PlayerSaveSanitizer.sanitize(.fresh)
        case .unsupportedNewerSchema:
            hadUnsupportedNewerSaveOnLoad = true
            save = PlayerSaveSanitizer.sanitize(.fresh)
        case .missing:
            save = PlayerSaveSanitizer.sanitize(.fresh)
        }
        invalidateRosterCache()
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        cancelDebouncedPersist()
        flushPendingPersistIfNeeded()

        var candidate = save
        update(&candidate)
        candidate = PlayerSaveSanitizer.sanitize(candidate)

        var lastWriteFailure = false
        for attempt in 0 ..< immediatePersistRetryCount {
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
        flushDebouncedPersistIfNeeded()

        guard let pending = pendingPersistSave else { return }

        do {
            try fileStore.save(pending)
            save = pending
            invalidateRosterCache()
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
        cancelDebouncedPersist()
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = save.sessionGeneration &+ 1
        try commitSave(fresh)
    }

    public func applyTestSeed() throws {
        cancelDebouncedPersist()
        try commitSave(.testSeed)
    }

    public func applyRemoteSave(_ remoteSave: PlayerSave) throws {
        guard remoteSave.schemaVersion <= PlayerSave.currentSchemaVersion else {
            throw PlayerSavePersistenceError.invalidSave("Remote save uses an unsupported schema version.")
        }
        cancelDebouncedPersist()
        let migrated = PlayerSaveSanitizer.sanitize(PlayerSaveMigration.migrate(remoteSave))
        try commitSave(migrated, stampLocalMutation: false, notifyLocalSave: false)
        loadedFromDisk = true
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try mutateThrowing(update)
        } catch let error as PlayerSavePersistenceError {
            lastPersistenceError = error
            if case .invalidSave = error {
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
        var prepared = candidate.markedLocalMutation()
        let persisted = PlayerSaveSanitizer.sanitize(prepared)
        try PlayerSaveSanitizer.validate(persisted)

        save = persisted
        loadedFromDisk = true
        lastPersistenceError = nil
        invalidateRosterCache()
        scheduleDebouncedPersist(persisted)
    }

    private func scheduleDebouncedPersist(_ candidate: PlayerSave) {
        debouncedPersistSave = candidate
        debouncedPersistTask?.cancel()

        guard persistDebounceNanoseconds > 0 else {
            flushDebouncedPersistIfNeeded()
            return
        }

        debouncedPersistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.persistDebounceNanoseconds ?? 0)
            guard !Task.isCancelled else { return }
            self?.flushDebouncedPersistIfNeeded()
        }
    }

    private func cancelDebouncedPersist() {
        debouncedPersistTask?.cancel()
        debouncedPersistTask = nil
        debouncedPersistSave = nil
    }

    private func flushDebouncedPersistIfNeeded() {
        debouncedPersistTask?.cancel()
        debouncedPersistTask = nil

        guard let candidate = debouncedPersistSave else { return }
        debouncedPersistSave = nil

        if isPersisting {
            debouncedPersistSave = candidate
            return
        }

        isPersisting = true
        defer {
            isPersisting = false
            if debouncedPersistSave != nil {
                flushDebouncedPersistIfNeeded()
            }
        }

        do {
            testSaveBarrier?()
            try fileStore.save(candidate)
            save = candidate
            loadedFromDisk = true
            pendingPersistSave = nil
            lastPersistenceError = nil
            invalidateRosterCache()
            onLocalSave?(save)
        } catch {
            lastPersistenceError = .writeFailed
            pendingPersistSave = candidate
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
        }
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
            debouncedPersistSave = nil
            lastPersistenceError = nil
            invalidateRosterCache()
            if notifyLocalSave {
                onLocalSave?(save)
            }
        } catch {
            lastPersistenceError = .writeFailed
            logger.error("Failed to persist player save: \(error.localizedDescription, privacy: .public)")
            if optimisticOnFailure {
                save = persisted
                pendingPersistSave = persisted
                invalidateRosterCache()
                if notifyLocalSave {
                    onLocalSave?(save)
                }
            } else {
                throw PlayerSavePersistenceError.writeFailed
            }
        }
    }

    private func resolvedRoster() -> PlayerRosterState {
        let inventoryIDs = Set(save.inventory.items.map(\.id))
        if let cachedRoster,
           cachedRosterSnapshot == save.roster,
           cachedRosterInventoryIDs == inventoryIDs {
            return cachedRoster
        }

        let hydrated = save.playerRoster(inventoryItemIDs: inventoryIDs)
        cachedRoster = hydrated
        cachedRosterSnapshot = save.roster
        cachedRosterInventoryIDs = inventoryIDs
        return hydrated
    }

    private func invalidateRosterCache() {
        cachedRoster = nil
        cachedRosterSnapshot = nil
        cachedRosterInventoryIDs = nil
    }
}
