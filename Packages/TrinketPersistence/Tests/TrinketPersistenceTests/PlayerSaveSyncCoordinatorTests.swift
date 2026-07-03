import XCTest
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSyncCoordinatorTests: XCTestCase {
    private var directoryURL: URL!
    private let earlier = Date(timeIntervalSince1970: 1600000000)
    private let later = Date(timeIntervalSince1970: 1800000000)
    private let testUploadDebounce: Duration = .milliseconds(10)

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerSaveSyncCoordinatorTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    func testUnavailableAccountSetsStatus() async {
        let mock = MockPlayerSaveSync()
        await mock.setAccountStatus(.unavailable("iCloud is signed out."))
        let store = PlayerSaveStore(fileStore: makeFileStore())
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()

        XCTAssertEqual(coordinator.status, .iCloudUnavailable("iCloud is signed out."))
        let fetchCount = await mock.fetchCallCount()
        XCTAssertEqual(fetchCount, 0)
    }

    func testNewerRemoteAppliesToStore() async throws {
        let mock = MockPlayerSaveSync()
        let fileStore = makeFileStore()
        try writeSave(makeSave(modifiedAt: earlier, gold: 10), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        let remote = RemotePlayerSave(
            save: makeSave(modifiedAt: later, gold: 99),
            modifiedAt: later,
            recordChangeTag: "remote"
        )
        await mock.setRemoteSave(remote)
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()

        XCTAssertEqual(coordinator.status, .upToDate)
        XCTAssertEqual(store.roster.gold, 99)
        let uploadCount = await mock.uploadedSaveCount()
        XCTAssertEqual(uploadCount, 0)
    }

    func testNewerLocalUploadsOnReconcile() async throws {
        let mock = MockPlayerSaveSync()
        let fileStore = makeFileStore()
        try writeSave(makeSave(modifiedAt: later, gold: 42), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        let remote = RemotePlayerSave(
            save: makeSave(modifiedAt: earlier, gold: 5),
            modifiedAt: earlier,
            recordChangeTag: "remote"
        )
        await mock.setRemoteSave(remote)
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()

        XCTAssertEqual(coordinator.status, .upToDate)
        let uploads = await mock.uploadedSavesSnapshot()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.roster.gold, 42)
    }

    func testEqualTimestampsKeepLocalWithoutUpload() async throws {
        let mock = MockPlayerSaveSync()
        let fileStore = makeFileStore()
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        try writeSave(makeSave(modifiedAt: timestamp, gold: 15), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        let remote = RemotePlayerSave(
            save: makeSave(modifiedAt: timestamp, gold: 99),
            modifiedAt: timestamp,
            recordChangeTag: "remote"
        )
        await mock.setRemoteSave(remote)
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()

        XCTAssertEqual(coordinator.status, .upToDate)
        XCTAssertEqual(store.roster.gold, 15)
        let uploadCount = await mock.uploadedSaveCount()
        XCTAssertEqual(uploadCount, 0)
    }

    func testLocalMutationSchedulesDebouncedUpload() async throws {
        let mock = MockPlayerSaveSync()
        let fileStore = makeFileStore()
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        try writeSave(makeSave(modifiedAt: timestamp, gold: 0), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        await mock.setRemoteSave(
            RemotePlayerSave(
                save: makeSave(modifiedAt: timestamp, gold: 0),
                modifiedAt: timestamp,
                recordChangeTag: "remote"
            )
        )
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()
        store.roster = updatedRoster(store.roster, gold: 33)

        let uploadCountBeforeDelay = await mock.uploadedSaveCount()
        XCTAssertEqual(uploadCountBeforeDelay, 0)

        await waitForUploadCount(1, on: mock)

        let uploads = await mock.uploadedSavesSnapshot()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.roster.gold, 33)
        XCTAssertEqual(coordinator.status, .upToDate)
    }

    func testApplyingRemoteSaveDoesNotScheduleUpload() async throws {
        let mock = MockPlayerSaveSync()
        let fileStore = makeFileStore()
        try writeSave(makeSave(modifiedAt: earlier, gold: 10), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        await mock.setRemoteSave(
            RemotePlayerSave(
                save: makeSave(modifiedAt: later, gold: 77),
                modifiedAt: later,
                recordChangeTag: "remote"
            )
        )
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()
        await waitPastUploadDebounce()

        XCTAssertEqual(store.roster.gold, 77)
        let uploadCount = await mock.uploadedSaveCount()
        XCTAssertEqual(uploadCount, 0)
    }

    func testFetchFailureSetsErrorStatus() async {
        let mock = MockPlayerSaveSync()
        await mock.setFetchError(MockSyncError.fetchFailed)
        let store = PlayerSaveStore(fileStore: makeFileStore())
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()

        XCTAssertEqual(coordinator.status, .error("Playing offline on this device."))
    }

    func testUploadFailureSetsOfflineStatus() async throws {
        let mock = MockPlayerSaveSync()
        await mock.setUploadError(MockSyncError.uploadFailed)
        let fileStore = makeFileStore()
        let timestamp = Date(timeIntervalSince1970: 1700000001)
        try writeSave(makeSave(modifiedAt: timestamp, gold: 0), to: fileStore)
        let store = PlayerSaveStore(fileStore: fileStore)
        await mock.setRemoteSave(
            RemotePlayerSave(
                save: makeSave(modifiedAt: timestamp, gold: 0),
                modifiedAt: timestamp,
                recordChangeTag: "remote"
            )
        )
        let coordinator = makeCoordinator(sync: mock, store: store)

        await coordinator.pullAndReconcile()
        store.roster = updatedRoster(store.roster, gold: 12)

        await waitForCoordinatorStatus(.offline, on: coordinator)
    }

    private func makeFileStore() -> PlayerSaveFileStore {
        SaveTestSupport.makeFileStore(directoryURL: directoryURL)
    }

    private func makeCoordinator(
        sync: MockPlayerSaveSync,
        store: PlayerSaveStore
    ) -> PlayerSaveSyncCoordinator {
        PlayerSaveSyncCoordinator(
            sync: sync,
            playerSaveStore: store,
            uploadDebounceInterval: testUploadDebounce
        )
    }

    private func waitForUploadCount(
        _ expected: Int,
        on mock: MockPlayerSaveSync,
        timeout: Duration = .seconds(1)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if await mock.uploadedSaveCount() >= expected {
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for \(expected) upload(s)")
    }

    private func waitForCoordinatorStatus(
        _ expected: PlayerSaveSyncStatus,
        on coordinator: PlayerSaveSyncCoordinator,
        timeout: Duration = .seconds(1)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if coordinator.status == expected {
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for status \(String(describing: expected))")
    }

    private func waitPastUploadDebounce() async {
        try? await Task.sleep(for: testUploadDebounce + .milliseconds(20))
    }

    private func makeSave(modifiedAt: Date, gold: Int) -> PlayerSave {
        var save = PlayerSave.fresh
        save.modifiedAt = modifiedAt
        save.roster.gold = gold
        return save
    }

    private func writeSave(_ save: PlayerSave, to fileStore: PlayerSaveFileStore) throws {
        fileStore.save(save)
    }

    private func updatedRoster(_ roster: PlayerRosterState, gold: Int) -> PlayerRosterState {
        var updated = roster
        updated.gold = gold
        return updated
    }
}

private enum MockSyncError: Error {
    case fetchFailed
    case uploadFailed
}

private actor MockPlayerSaveSync: PlayerSaveSyncing {
    private var accountStatusResult: PlayerSaveAccountStatus = .available
    private var remoteSave: RemotePlayerSave?
    private var fetchError: Error?
    private var uploadError: Error?
    private var uploadedSaves: [PlayerSave] = []
    private var fetchCount = 0
    private var subscribeCallCount = 0

    func setAccountStatus(_ status: PlayerSaveAccountStatus) {
        accountStatusResult = status
    }

    func setRemoteSave(_ remote: RemotePlayerSave?) {
        remoteSave = remote
    }

    func setFetchError(_ error: Error?) {
        fetchError = error
    }

    func setUploadError(_ error: Error?) {
        uploadError = error
    }

    func uploadedSaveCount() -> Int {
        uploadedSaves.count
    }

    func uploadedSavesSnapshot() -> [PlayerSave] {
        uploadedSaves
    }

    func fetchCallCount() -> Int {
        fetchCount
    }

    func accountStatus() async -> PlayerSaveAccountStatus {
        await Task.yield()
        return accountStatusResult
    }

    func fetchRemoteSave() async throws -> RemotePlayerSave? {
        await Task.yield()
        fetchCount += 1
        if let fetchError {
            throw fetchError
        }
        return remoteSave
    }

    func upload(_ save: PlayerSave) async throws {
        await Task.yield()
        if let uploadError {
            throw uploadError
        }
        uploadedSaves.append(save)
    }

    func subscribeToChanges() async throws {
        await Task.yield()
        subscribeCallCount += 1
    }
}
