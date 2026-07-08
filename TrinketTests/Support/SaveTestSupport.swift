import Foundation
import TrinketPersistence
@testable import Trinket

enum SaveTestSupport {
    static func makeTempDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix).\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func makeStoreURL(directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("PlayerSave.sqlite")
    }

    @MainActor
    static func makeSaveStore(directoryURL: URL) -> PlayerSaveStore {
        PlayerSaveStore(
            storeURL: makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true
        )
    }
}
