import Foundation
import os
import SwiftData

enum ModelContainerBootstrap {
    struct OpenResult {
        let container: ModelContainer
        let usedInMemoryFallback: Bool
        let recoveredAfterStoreDeletion: Bool
    }

    static func open(
        schema: Schema,
        primaryConfiguration: ModelConfiguration,
        logger: Logger,
        logLabel: String,
        storeURLForRecovery: URL? = nil,
        deleteStoreOnFailure: Bool = true
    ) throws -> OpenResult {
        do {
            let container = try ModelContainer(for: schema, configurations: primaryConfiguration)
            return OpenResult(container: container, usedInMemoryFallback: false, recoveredAfterStoreDeletion: false)
        } catch {
            logger.error(
                "Failed to open \(logLabel, privacy: .public) store: \(error.localizedDescription, privacy: .public)"
            )

            if deleteStoreOnFailure, let storeURL = storeURLForRecovery {
                deleteStoreFiles(at: storeURL, logger: logger, logLabel: logLabel)
                if let recovered = try? ModelContainer(for: schema, configurations: primaryConfiguration) {
                    logger.notice("Recovered \(logLabel, privacy: .public) store after deleting corrupt files.")
                    return OpenResult(
                        container: recovered,
                        usedInMemoryFallback: false,
                        recoveredAfterStoreDeletion: true
                    )
                }
            }

            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: fallbackConfig)
                logger.notice("\(logLabel, privacy: .public) store opened in-memory fallback.")
                return OpenResult(container: container, usedInMemoryFallback: true, recoveredAfterStoreDeletion: false)
            } catch let fallbackError {
                logger.fault(
                    "Failed to open in-memory fallback for \(logLabel, privacy: .public): \(fallbackError.localizedDescription, privacy: .public)"
                )
                throw PlayerSavePersistenceError.storeUnavailable(
                    "Could not open \(logLabel) persistence (\(fallbackError.localizedDescription))."
                )
            }
        }
    }

    private static func deleteStoreFiles(at url: URL, logger: Logger, logLabel: String) {
        let base = url.deletingPathExtension()
        let candidates = [
            url,
            base.appendingPathExtension("store-shm"),
            base.appendingPathExtension("store-wal"),
            base.appendingPathExtension("sqlite-shm"),
            base.appendingPathExtension("sqlite-wal")
        ]
        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            do {
                try FileManager.default.removeItem(at: candidate)
            } catch {
                logger.error(
                    "Failed to delete \(logLabel, privacy: .public) store file \(candidate.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}
