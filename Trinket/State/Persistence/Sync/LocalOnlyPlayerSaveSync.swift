import Foundation

struct LocalOnlyPlayerSaveSync: PlayerSaveSyncing {
    func accountStatus() async -> PlayerSaveAccountStatus {
        .unavailable("iCloud sync is disabled.")
    }

    func fetchRemoteSave() async throws -> RemotePlayerSave? {
        nil
    }

    func upload(_: PlayerSave) async throws {}

    func subscribeToChanges() async throws {}
}
