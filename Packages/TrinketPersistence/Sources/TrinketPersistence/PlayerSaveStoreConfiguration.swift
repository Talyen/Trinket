import Foundation
import os
import SwiftData

/// Store URL / ModelConfiguration helpers for `PlayerSaveStore`.
/// Keeps container-open plumbing out of the save hub body.
enum PlayerSaveStoreConfiguration {
    static func resolveStoreURL(storeName: String?, storeURL: URL?) -> URL {
        if let storeName {
            return URL.applicationSupportDirectory.appending(path: "\(storeName).store")
        } else {
            return storeURL ?? URL.applicationSupportDirectory.appending(path: "default.store")
        }
    }

    static func cleanStoreFiles(at url: URL) {
        let shmURL = url.deletingPathExtension().appendingPathExtension("store-shm")
        let walURL = url.deletingPathExtension().appendingPathExtension("store-wal")
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: shmURL)
        try? FileManager.default.removeItem(at: walURL)
    }

    static func resolveConfiguration(
        schema: Schema,
        finalURL: URL,
        storeName: String?,
        storeURL: URL?,
        disableCloudSync: Bool,
        inMemoryOnly: Bool,
        cloudKitContainerIdentifier: String
    ) -> (config: ModelConfiguration, recoveryURL: URL?) {
        if inMemoryOnly {
            return (ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none), nil)
        } else if storeName != nil {
            return (ModelConfiguration(schema: schema, url: finalURL, cloudKitDatabase: .none), finalURL)
        } else if let storeURL {
            return (ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none), storeURL)
        } else if disableCloudSync {
            return (ModelConfiguration(schema: schema, cloudKitDatabase: .none), nil)
        } else {
            return (
                ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudKitContainerIdentifier)),
                nil
            )
        }
    }

    static func fetchRoot(in context: ModelContext, logger: Logger) -> PlayerSaveRoot? {
        let descriptor = FetchDescriptor<PlayerSaveRoot>()
        do {
            return try context.fetch(descriptor).first { $0.id == "primary" }
        } catch {
            logger.error(
                "Failed to fetch player save root: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    static func clearSaveRoot(in context: ModelContext, logger: Logger) {
        do {
            try context.delete(model: PlayerSaveRoot.self)
            try context.save()
        } catch {
            logger.error(
                "Failed to clear player save during reset: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
