import Foundation
import TrinketPersistence
@testable import Trinket

@MainActor
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

    static func makeFileStore(directoryURL: URL) -> PlayerSaveFileStore {
        PlayerSaveFileStore(directoryURL: directoryURL)
    }

    static func makeSaveStore(directoryURL: URL) -> PlayerSaveStore {
        PlayerSaveStore(
            fileStore: makeFileStore(directoryURL: directoryURL),
            persistDebounceNanoseconds: 0
        )
    }
}
