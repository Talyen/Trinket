import Foundation
import os
import SwiftData

enum ModelContainerBootstrap {
    struct OpenResult {
        let container: ModelContainer
        let usedInMemoryFallback: Bool
    }

    static func open(
        schema: Schema,
        primaryConfiguration: ModelConfiguration,
        logger: Logger,
        logLabel: String,
    ) throws -> OpenResult {
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: primaryConfiguration,
            )
            return OpenResult(container: container, usedInMemoryFallback: false)
        } catch {
            logger.error(
                "Failed to open \(logLabel, privacy: .public) store: \(error.localizedDescription, privacy: .public)",
            )

            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: fallbackConfig,
                )
                logger.notice("\(logLabel, privacy: .public) store opened in-memory fallback.")
                return OpenResult(container: container, usedInMemoryFallback: true)
            } catch {
                logger.fault(
                    "Failed to open in-memory fallback for \(logLabel, privacy: .public): \(error.localizedDescription, privacy: .public)",
                )
                throw PlayerSavePersistenceError.storeUnavailable(
                    "Could not open \(logLabel) persistence (\(error.localizedDescription)).",
                )
            }
        }
    }

    static func deleteStoreFiles(at url: URL, logger: Logger, logLabel: String) {
        let candidates = ["", "-shm", "-wal", "-journal"].map { suffix in
            url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + suffix)
        }
        for candidate in candidates {
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            do {
                try FileManager.default.removeItem(at: candidate)
            } catch {
                logger.error(
                    "Failed to delete \(logLabel, privacy: .public) store file \(candidate.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)",
                )
            }
        }
    }
}
