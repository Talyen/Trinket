import Foundation
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

    func makeSaveStore() -> PlayerSaveStore {
        SaveTestSupport.makeSaveStore(directoryURL: directoryURL)
    }
}
