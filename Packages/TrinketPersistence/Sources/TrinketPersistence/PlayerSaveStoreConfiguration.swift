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

    static func resolveConfiguration(
        schema: Schema,
        finalURL _: URL,
        storeName: String?,
        storeURL: URL?,
        disableCloudSync: Bool,
        inMemoryOnly: Bool,
        cloudKitContainerIdentifier: String,
    ) -> (config: ModelConfiguration, recoveryURL: URL?) {
        let resolved = resolveStore(
            schema: schema,
            storeName: storeName,
            storeURL: storeURL,
            disableCloudSync: disableCloudSync,
            inMemoryOnly: inMemoryOnly,
            cloudKitContainerIdentifier: cloudKitContainerIdentifier,
        )
        return (resolved.config, resolved.recoveryURL)
    }

    static func fetchRoot(in context: ModelContext, logger: Logger) throws -> PlayerSaveRoot? {
        let descriptor = FetchDescriptor<PlayerSaveRoot>(
            predicate: #Predicate { $0.id == "primary" },
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
        guard let keeper = primaries.max(by: Self.isOlderPrimary(_:than:)) else {
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
            throw PlayerSavePersistenceError.writeFailed
        }
        return keeper
    }

    private static func isOlderPrimary(_ lhs: PlayerSaveRoot, than rhs: PlayerSaveRoot) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return lhs.modifiedAt < rhs.modifiedAt
        }
        if lhs.sessionGeneration != rhs.sessionGeneration {
            return lhs.sessionGeneration < rhs.sessionGeneration
        }
        return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
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
