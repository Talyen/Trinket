import XCTest
import TrinketCore
import TrinketContent
@testable import TrinketPersistence

@MainActor
struct SyncCoordinatorTestFixture {
    let mock: MockPlayerSaveSync
    let store: PlayerSaveStore
    let coordinator: PlayerSaveSyncCoordinator

    static func make(
        directoryURL: URL,
        localSave: PlayerSave? = nil,
        remoteSave: RemotePlayerSave? = nil,
        accountStatus: PlayerSaveAccountStatus = .available,
        fetchError: Error? = nil,
        uploadError: Error? = nil
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
        let store = PlayerSaveStore(
            fileStore: fileStore,
            persistDebounceNanoseconds: 0
        )
        let coordinator = PlayerSaveSyncCoordinator(
            sync: mock,
            playerSaveStore: store
        )

        return SyncCoordinatorTestFixture(
            mock: mock,
            store: store,
            coordinator: coordinator
        )
    }
}
