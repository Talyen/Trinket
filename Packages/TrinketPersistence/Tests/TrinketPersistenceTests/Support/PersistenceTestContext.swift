import Foundation
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PersistenceTestContext {
    let directoryURL: URL

    nonisolated init() throws {
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PersistenceTest")
    }

    deinit {
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    func storeURL() -> URL {
        SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
    }

    func makeSaveStore(
        inMemoryOnly: Bool = false,
        persistImmediately: Bool = true,
        resetState: Bool = false,
    ) throws -> PlayerSaveStore {
        try SaveTestSupport.makeSaveStore(
            directoryURL: directoryURL,
            persistImmediately: persistImmediately,
            resetState: resetState,
            inMemoryOnly: inMemoryOnly,
        )
    }

    func makeReloadedStore(
        persistImmediately: Bool = true,
    ) throws -> PlayerSaveStore {
        try PlayerSaveStore(
            storeURL: storeURL(),
            disableCloudSync: true,
            persistSaveImmediately: persistImmediately,
        )
    }
}
