import Foundation

public struct LocalOnlyPlayerSaveSync: PlayerSaveSyncing {
    public init() {}

    public func accountStatus() async -> PlayerSaveAccountStatus {
        await Task.yield()
        return .unavailable("iCloud sync is disabled.")
    }

    public func fetchRemoteSave() async throws -> RemotePlayerSave? {
        await Task.yield()
        return nil
    }

    public func upload(_: PlayerSave) async throws {
        await Task.yield()
    }

    public func subscribeToChanges() async throws {
        await Task.yield()
    }
}
