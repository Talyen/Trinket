import Foundation
import Observation
import SwiftData
import os

@MainActor
@Observable
public final class PlayerSaveStore {
    public static let cloudKitContainerIdentifier = "iCloud.com.ryanmcintire.Trinket"

    private let container: ModelContainer
    private let context: ModelContext
    private var root: PlayerSaveRoot
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "PlayerSave"
    )

    public private(set) var lastPersistenceError: PlayerSavePersistenceError?

    #if DEBUG
    var forcesNextSaveFailure = false
    #endif

    public var journey: JourneyProgressState {
        get { currentSave.journey }
        set { mutate { $0.journey = PlayerSaveSanitizer.sanitizeJourney(newValue) } }
    }

    public var roster: PlayerRosterState {
        get { currentSave.playerRoster(inventoryItemIDs: Set(currentSave.inventory.items.map(\.id))) }
        set { mutate { $0.roster = SavedRosterState(newValue) } }
    }

    public var inventory: PlayerInventoryState {
        get { currentSave.inventory.inventory() }
        set { mutate { $0.inventory = SavedInventoryState(newValue) } }
    }

    public var homestead: PlayerHomesteadState {
        get { currentSave.homestead.homestead() }
        set { mutate { $0.homestead = SavedHomesteadState(newValue) } }
    }

    public var currentSave: PlayerSave {
        root.toPlayerSave()
    }

    public init(
        storeName: String? = nil,
        storeURL: URL? = nil,
        disableCloudSync: Bool = false,
        resetState: Bool = false,
        inMemoryOnly: Bool = false
    ) {
        let finalURL: URL
        if let storeName {
            finalURL = URL.applicationSupportDirectory.appending(path: "\(storeName).store")
        } else {
            finalURL = storeURL ?? URL.applicationSupportDirectory.appending(path: "default.store")
        }

        if resetState && !inMemoryOnly {
            let shmURL = finalURL.deletingPathExtension().appendingPathExtension("store-shm")
            let walURL = finalURL.deletingPathExtension().appendingPathExtension("store-wal")
            try? FileManager.default.removeItem(at: finalURL)
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)
        }

        let schema = PlayerSaveGraph.schema
        let config: ModelConfiguration
        if inMemoryOnly {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if storeName != nil {
            config = ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none)
        } else if let storeURL {
            config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else if disableCloudSync {
            config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
            )
        }

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            logger.error("Failed to open SwiftData player store: \(error.localizedDescription, privacy: .public)")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: fallbackConfig)
            } catch {
                fatalError("Failed to open fallback in-memory SwiftData store: \(error.localizedDescription)")
            }
        }
        context = ModelContext(container)
        context.autosaveEnabled = false

        if resetState {
            try? context.delete(model: PlayerSaveRoot.self)
            try? context.save()
        }

        if let existingRoot = Self.fetchRoot(in: context) {
            root = existingRoot
            ensureRequiredGraph()
        } else {
            let newRoot = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(.fresh))
            context.insert(newRoot)
            root = newRoot
            try? context.save()
        }
    }

    public func performBatchMutation(_ update: (inout PlayerSave) -> Void) throws {
        let snapshot = currentSave
        var candidate = snapshot
        update(&candidate)
        candidate.modifiedAt = Date()
        candidate = PlayerSaveSanitizer.sanitize(candidate)
        try PlayerSaveSanitizer.validate(candidate)
        root.update(from: candidate)

        do {
            #if DEBUG
            if forcesNextSaveFailure {
                forcesNextSaveFailure = false
                throw NSError(domain: "PlayerSaveStoreTests", code: 1)
            }
            #endif
            try context.save()
            lastPersistenceError = nil
        } catch {
            root.update(from: snapshot)
            lastPersistenceError = .writeFailed
            logger.error("Failed to save SwiftData player graph: \(error.localizedDescription, privacy: .public)")
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    private func resetRoot(with save: PlayerSave) throws {
        try? context.delete(model: PlayerSaveRoot.self)
        try? context.save()

        let newRoot = PlayerSaveRoot(save: PlayerSaveSanitizer.sanitize(save))
        context.insert(newRoot)
        try saveGraph()

        self.root = newRoot
    }

    public func resetGameplayProgress() throws {
        var fresh = PlayerSave.fresh
        fresh.sessionGeneration = currentSave.sessionGeneration &+ 1
        try resetRoot(with: fresh)
    }

    public func applyTestSeed() throws {
        try resetRoot(with: .testSeed)
    }

    private func mutate(_ update: (inout PlayerSave) -> Void) {
        do {
            try performBatchMutation(update)
        } catch let error as PlayerSavePersistenceError {
            lastPersistenceError = error
            logger.error("Failed to persist player graph mutation: \(error.localizedDescription, privacy: .public)")
        } catch {
            lastPersistenceError = .writeFailed
            logger.error("Failed to persist player graph mutation: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveGraph() throws {
        do {
            try context.save()
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = .writeFailed
            throw PlayerSavePersistenceError.writeFailed
        }
    }

    private func ensureRequiredGraph() {
        var save = currentSave
        save = PlayerSaveSanitizer.sanitize(save)
        root.update(from: save)
        try? context.save()
    }

    private static func fetchRoot(in context: ModelContext) -> PlayerSaveRoot? {
        let descriptor = FetchDescriptor<PlayerSaveRoot>()
        return try? context.fetch(descriptor).first { $0.id == "primary" }
    }
}
