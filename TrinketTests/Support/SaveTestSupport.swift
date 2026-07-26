import Foundation
import TrinketPersistence

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
    static func makeSaveStore(directoryURL: URL, persistImmediately: Bool = true) throws -> PlayerSaveStore {
        try PlayerSaveStore(
            storeURL: makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true,
            persistSaveImmediately: persistImmediately
        )
    }

    static func makeSave(modifiedAt: Date, gold: Int = 0) -> PlayerSave {
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart
        )
        save.roster.gold = gold
        return save
    }
}
