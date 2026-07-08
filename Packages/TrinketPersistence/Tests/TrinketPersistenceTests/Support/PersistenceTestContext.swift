import Foundation
import TrinketTestSupport
@testable import TrinketPersistence

@MainActor
final class PersistenceTestContext {
    let directoryURL: URL

    init() throws {
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PersistenceTest")
    }

    deinit {
        SaveTestSupport.removeTempDirectory(directoryURL)
    }

    func storeURL() -> URL {
        SaveTestSupport.makeStoreURL(directoryURL: directoryURL)
    }

    func makeSaveStore() throws -> PlayerSaveStore {
        try SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
    }
}
