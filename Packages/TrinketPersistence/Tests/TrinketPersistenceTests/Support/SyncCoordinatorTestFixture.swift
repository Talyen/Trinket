import Foundation
@testable import TrinketPersistence

@MainActor
struct SyncCoordinatorTestFixture {
    static let defaultUploadDebounce: Duration = .milliseconds(10)

    let mock: MockPlayerSaveSync
    let store: PlayerSaveStore
    let coordinator: PlayerSaveSyncCoordinator
    let uploadDebounce: Duration

    static func make(
        directoryURL: URL,
        localSave: PlayerSave? = nil,
        remoteSave: RemotePlayerSave? = nil,
        accountStatus: PlayerSaveAccountStatus = .available,
        fetchError: Error? = nil,
        uploadError: Error? = nil,
        uploadDebounce: Duration = defaultUploadDebounce
    ) async throws -> SyncCoordinatorTestFixture {
        let mock = MockPlayerSaveSync()
        await mock.setAccountStatus(accountStatus)
        await mock.setRemoteSave(remoteSave)
        await mock.setFetchError(fetchError)
        await mock.setUploadError(uploadError)

        let fileStore = SaveTestSupport.makeFileStore(directoryURL: directoryURL)
        if let localSave {
            try SaveTestSupport.writeSave(localSave, to: fileStore)
        }
        let store = PlayerSaveStore(fileStore: fileStore)
        let coordinator = PlayerSaveSyncCoordinator(
            sync: mock,
            playerSaveStore: store,
            uploadDebounceInterval: uploadDebounce
        )

        return SyncCoordinatorTestFixture(
            mock: mock,
            store: store,
            coordinator: coordinator,
            uploadDebounce: uploadDebounce
        )
    }

    func waitPastUploadDebounce() async {
        try? await Task.sleep(for: uploadDebounce + .milliseconds(20))
    }
}
