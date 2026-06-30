import Foundation

struct LocalOnlyPlayerSaveSync: PlayerSaveSyncing {
    func accountStatus() async -> PlayerSaveAccountStatus {
        await Task.yield()
        return .unavailable("iCloud sync is disabled.")
    }

    func fetchRemoteSave() async throws -> RemotePlayerSave? {
        await Task.yield()
        return nil
    }

    func upload(_: PlayerSave) async throws {
        await Task.yield()
    }

    func subscribeToChanges() async throws {
        await Task.yield()
    }
}
