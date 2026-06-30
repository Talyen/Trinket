import Foundation

struct RemotePlayerSave: Equatable, Sendable {
    let save: PlayerSave
    let modifiedAt: Date
    let recordChangeTag: String?
}

protocol PlayerSaveSyncing: Sendable {
    func accountStatus() async -> PlayerSaveAccountStatus
    func fetchRemoteSave() async throws -> RemotePlayerSave?
    func upload(_ save: PlayerSave) async throws
    func subscribeToChanges() async throws
}
