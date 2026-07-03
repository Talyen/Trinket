import Foundation

public struct RemotePlayerSave: Equatable, Sendable {
    public let save: PlayerSave
    public let modifiedAt: Date
    public let recordChangeTag: String?

    public init(save: PlayerSave, modifiedAt: Date, recordChangeTag: String?) {
        self.save = save
        self.modifiedAt = modifiedAt
        self.recordChangeTag = recordChangeTag
    }
}

public protocol PlayerSaveSyncing: Sendable {
    func accountStatus() async -> PlayerSaveAccountStatus
    func fetchRemoteSave() async throws -> RemotePlayerSave?
    func upload(_ save: PlayerSave, replacingRecordChangeTag: String?) async throws -> String?
    func subscribeToChanges() async throws
}

public extension PlayerSaveSyncing {
    func upload(_ save: PlayerSave) async throws {
        _ = try await upload(save, replacingRecordChangeTag: nil)
    }
}
