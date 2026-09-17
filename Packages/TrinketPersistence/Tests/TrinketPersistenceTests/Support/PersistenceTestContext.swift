import Foundation
import SwiftData
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

    nonisolated func storeURL() -> URL {
        SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
    }

    func makeSaveStore(
        inMemoryOnly: Bool = false,
        resetState: Bool = false,
    ) throws -> PlayerSaveStore {
        try SaveTestSupport.makeSaveStore(
            directoryURL: directoryURL,
            resetState: resetState,
            inMemoryOnly: inMemoryOnly,
        )
    }

    /// In-memory store without touching the temp directory on disk.
    func makeInMemoryStore() throws -> PlayerSaveStore {
        try PlayerSaveStore(disableCloudSync: true, inMemoryOnly: true)
    }

    /// Test-side graph inspection without reopening the store.
    nonisolated func makeSideContext() throws -> ModelContext {
        try SaveTestSupport.makeSideContext(storeURL: storeURL())
    }

    nonisolated func makeContainer() throws -> ModelContainer {
        try SaveTestSupport.makeContainer(storeURL: storeURL())
    }

    /// Single construction path: a reload is just a default open of the same
    /// URL, so it forwards through `makeSaveStore` instead of constructing
    /// `PlayerSaveStore` directly.
    func makeReloadedStore() throws -> PlayerSaveStore {
        try makeSaveStore()
    }

    func seedAndReload(_ save: PlayerSave) throws -> PlayerSaveStore {
        try SaveTestSupport.writeRoot(save, to: storeURL())
        return try makeReloadedStore()
    }
}
