import Foundation
import os
import SwiftData

enum PlayerSaveStoreConfiguration {
    struct ResolvedStore {
        let config: ModelConfiguration
        let recoveryURL: URL?
        let finalURL: URL
    }

    static func resolveStoreURL(storeName: String?, storeURL: URL?) -> URL {
        if let storeName {
            URL.applicationSupportDirectory.appending(path: "\(storeName).store")
        } else {
            storeURL ?? URL.applicationSupportDirectory.appending(path: "default.store")
        }
    }

    static func cleanStoreFiles(at url: URL) {
        let logger = Logger(
            subsystem: PlayerSaveDefaults.loggingSubsystem,
            category: "StoreCleanup",
        )
        ModelContainerBootstrap.deleteStoreFiles(at: url, logger: logger, logLabel: "player save")
    }

    static func resolveStore(
        schema: Schema,
        storeName: String?,
        storeURL: URL?,
        disableCloudSync: Bool,
        inMemoryOnly: Bool,
        cloudKitContainerIdentifier: String,
    ) -> ResolvedStore {
        let finalURL = resolveStoreURL(storeName: storeName, storeURL: storeURL)
        let resolved: (ModelConfiguration, URL?) = {
            if inMemoryOnly {
                return (ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none), nil)
            }
            if storeName != nil {
                return (ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none), finalURL)
            }
            if let storeURL {
                return (ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none), storeURL)
            }
            if disableCloudSync {
                return (ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none), finalURL)
            }
            return (
                ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerIdentifier)),
                nil,
            )
        }()
        return ResolvedStore(config: resolved.0, recoveryURL: resolved.1, finalURL: finalURL)
    }

    static func fetchRoot(in context: ModelContext, logger: Logger) throws -> PlayerSaveRoot? {
        let descriptor = FetchDescriptor<PlayerSaveRoot>(
            predicate: #Predicate { $0.id == "primary" },
            sortBy: [
                SortDescriptor(\.modifiedAt, order: .reverse),
                SortDescriptor(\.sessionGeneration, order: .reverse),
            ],
        )
        let primaries: [PlayerSaveRoot]
        do {
            primaries = try context.fetch(descriptor)
        } catch {
            logger.error(
                "Failed to fetch player save root: \(error.localizedDescription, privacy: .public)",
            )
            throw PlayerSavePersistenceError.storeUnavailable(
                "Couldn't read saved progress from this device.",
            )
        }
        guard let keeper = primaries.first else {
            return nil
        }
        let extras = primaries.filter { $0 !== keeper }
        guard !extras.isEmpty else { return keeper }
        logger.notice(
            "Dropped \(extras.count, privacy: .public) duplicate player save roots; kept the newest primary.",
        )
        for extra in extras {
            context.delete(extra)
        }
        do {
            try context.save()
        } catch {
            logger.error(
                "Failed to drop duplicate player save roots: \(error.localizedDescription, privacy: .public)",
            )
            context.rollback()
        }
        return keeper
    }

    static func clearSaveRoot(in context: ModelContext, logger: Logger) throws {
        do {
            try context.delete(model: PlayerSaveRoot.self)
            try context.save()
        } catch {
            logger.error(
                "Failed to clear player save during reset: \(error.localizedDescription, privacy: .public)",
            )
            throw PlayerSavePersistenceError.writeFailed
        }
    }
}
