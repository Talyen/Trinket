import Foundation
@testable import TrinketPersistence

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

    static func makeStoreURL(directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("PlayerSave.sqlite")
    }

    static func makeSaveStore(directoryURL: URL) -> PlayerSaveStore {
        PlayerSaveStore(
            storeURL: makeStoreURL(directoryURL: directoryURL),
            disableCloudSync: true
        )
    }

    nonisolated static func makeSave(modifiedAt: Date, gold: Int = 0) -> PlayerSave {
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )
        save.roster.gold = gold
        return save
    }
}

@MainActor
extension PlayerSaveStore {
    func setGoldForTests(_ gold: Int) {
        var updated = roster
        updated.gold = gold
        roster = updated
    }

    func grantGoldForTests(_ amount: Int) {
        var updated = roster
        updated.grantGold(amount)
        roster = updated
    }
}
