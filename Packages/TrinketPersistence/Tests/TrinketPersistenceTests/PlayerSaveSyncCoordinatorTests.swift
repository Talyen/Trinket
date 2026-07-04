import XCTest
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSyncCoordinatorTests: XCTestCase {
    private var directoryURL: URL!
    private let earlier = Date(timeIntervalSince1970: 1600000000)
    private let later = Date(timeIntervalSince1970: 1800000000)
    private let syncedAt = Date(timeIntervalSince1970: 1700000000)

    override func setUp() async throws {
        try await super.setUp()
        directoryURL = try SaveTestSupport.makeTempDirectory(prefix: "PlayerSaveSyncCoordinatorTests")
    }

    override func tearDown() async throws {
        SaveTestSupport.removeTempDirectory(directoryURL)
        try await super.tearDown()
    }

    // MARK: - Lifecycle

    func testStartReconcilesAndSubscribesWhenAvailable() async throws {
        let fixture = try await makeSyncedFixture()
        await fixture.coordinator.start()

        XCTAssertEqual(fixture.coordinator.status, .upToDate)
        XCTAssertEqual(fixture.coordinator.sessionPhase, .active)
        XCTAssertNotNil(fixture.coordinator.sessionToken)
        let fetchCount = await fixture.mock.fetchCallCount()
        let subscribeCount = await fixture.mock.subscribeInvocationCount()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(subscribeCount, 1)
    }

    func testStartSkipsSubscribeWhenUnavailable() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            accountStatus: .unavailable("iCloud is signed out.")
        )
        await fixture.coordinator.start()

        XCTAssertEqual(fixture.coordinator.status, .iCloudUnavailable("iCloud is signed out."))
        let fetchCount = await fixture.mock.fetchCallCount()
        let subscribeCount = await fixture.mock.subscribeInvocationCount()
        XCTAssertEqual(fetchCount, 0)
        XCTAssertEqual(subscribeCount, 0)
    }

    // MARK: - Reconcile

    func testUnavailableAccountSetsStatusWithoutFetch() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            accountStatus: .unavailable("iCloud is signed out.")
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.coordinator.status, .iCloudUnavailable("iCloud is signed out."))
        let fetchCount = await fixture.mock.fetchCallCount()
        XCTAssertEqual(fetchCount, 0)
    }

    func testReconcileAppliesNewerRemoteToStore() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 10),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 99)
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.coordinator.status, .upToDate)
        XCTAssertEqual(fixture.store.roster.gold, 99)
        let fetchCount = await fixture.mock.fetchCallCount()
        let uploadCount = await fixture.mock.uploadedSaveCount()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(uploadCount, 0)
    }

    func testReconcileMergesWhenSessionGenerationMatches() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: later, gold: 42),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: earlier, gold: 5)
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.coordinator.status, .upToDate)
        XCTAssertEqual(fixture.store.roster.gold, 42)
        let fetchCount = await fixture.mock.fetchCallCount()
        let uploadCount = await fixture.mock.uploadedSaveCount()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(uploadCount, 0)
    }

    func testRemoteMissingUploadsLocalOnReconcile() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 25),
            remoteSave: nil
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.coordinator.status, .upToDate)
        let uploads = await fixture.mock.uploadedSavesSnapshot()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.roster.gold, 25)
    }

    func testApplyingRemoteSaveDoesNotScheduleUpload() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 10),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 77)
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.store.roster.gold, 77)
        let uploadCount = await fixture.mock.uploadedSaveCount()
        XCTAssertEqual(uploadCount, 0)
    }

    func testPullAndReconcileIgnoredDuringActiveSession() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 10),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 99)
        )
        await fixture.coordinator.start()
        XCTAssertEqual(fixture.store.roster.gold, 99)

        fixture.store.setGoldForTests(55)
        await fixture.mock.setRemoteSave(SaveTestSupport.makeRemote(modifiedAt: later, gold: 12))
        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.store.roster.gold, 55)
    }

    // MARK: - Checkpoint upload

    func testLocalMutationDuringActiveSessionDefersUploadUntilCheckpoint() async throws {
        let fixture = try await makeSyncedFixture()
        await fixture.coordinator.start()
        fixture.store.setGoldForTests(33)

        let uploadCountBeforeCheckpoint = await fixture.mock.uploadedSaveCount()
        XCTAssertEqual(uploadCountBeforeCheckpoint, 0)

        await fixture.coordinator.checkpointUploadIfNeeded()
        await fixture.mock.waitUntilUploadCount(atLeast: 1)

        let uploads = await fixture.mock.uploadedSavesSnapshot()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.roster.gold, 33)
        XCTAssertEqual(fixture.coordinator.status, .upToDate)
    }

    func testRapidMutationsUploadLatestCheckpoint() async throws {
        let fixture = try await makeSyncedFixture()
        await fixture.coordinator.start()
        fixture.store.grantGoldForTests(10)
        fixture.store.grantGoldForTests(5)

        await fixture.coordinator.checkpointUploadIfNeeded()
        await fixture.mock.waitUntilUploadCount(atLeast: 1)

        let uploads = await fixture.mock.uploadedSavesSnapshot()
        XCTAssertEqual(uploads.count, 1)
        XCTAssertEqual(uploads.first?.roster.gold, 15)
    }

    func testUnavailableAccountDuringCheckpointSetsStatus() async throws {
        let fixture = try await makeSyncedFixture()
        await fixture.coordinator.start()
        await fixture.mock.setAccountStatus(.unavailable("iCloud is signed out."))
        fixture.store.setGoldForTests(20)

        await fixture.coordinator.checkpointUploadIfNeeded()

        XCTAssertEqual(fixture.coordinator.status, .iCloudUnavailable("iCloud is signed out."))
        let uploadCount = await fixture.mock.uploadedSaveCount()
        XCTAssertEqual(uploadCount, 0)
    }

    // MARK: - Error handling

    func testFetchFailureSetsErrorStatus() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            fetchError: MockSyncError.fetchFailed
        )

        await fixture.coordinator.pullAndReconcile()

        XCTAssertEqual(fixture.coordinator.status, .error("Playing offline on this device."))
        let fetchCount = await fixture.mock.fetchCallCount()
        XCTAssertEqual(fetchCount, 1)
    }

    func testUploadFailureSetsOfflineStatusAndPreservesLocalGold() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 0),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 0),
            uploadError: MockSyncError.uploadFailed
        )
        await fixture.coordinator.start()
        fixture.store.setGoldForTests(12)

        await fixture.coordinator.checkpointUploadIfNeeded()

        await AsyncTestSupport.waitUntil("offline status after upload failure") {
            fixture.coordinator.status == .offline
        }

        XCTAssertEqual(fixture.store.roster.gold, 12)
    }

    func testCloseSessionReleasesLeaseAndReturnsToClosed() async throws {
        let fixture = try await makeSyncedFixture()
        await fixture.coordinator.start()
        XCTAssertEqual(fixture.coordinator.sessionPhase, .active)

        await fixture.coordinator.closeSession()

        XCTAssertEqual(fixture.coordinator.sessionPhase, .closed)
        XCTAssertNil(fixture.coordinator.sessionToken)
    }

    func testUploadConflictMergesAndRetriesUpload() async throws {
        let fixture = try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 10),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 20, recordChangeTag: "tag-v1")
        )
        await fixture.coordinator.start()
        XCTAssertEqual(fixture.store.roster.gold, 20)

        fixture.store.setGoldForTests(50)
        await fixture.mock.setRemoteSave(
            SaveTestSupport.makeRemote(modifiedAt: later, gold: 99, recordChangeTag: "tag-v2")
        )

        await fixture.coordinator.checkpointUploadIfNeeded()
        await fixture.mock.waitUntilUploadCount(atLeast: 1)

        XCTAssertEqual(fixture.coordinator.status, .upToDate)
        let uploads = await fixture.mock.uploadedSavesSnapshot()
        XCTAssertGreaterThanOrEqual(uploads.count, 1)
    }

    // MARK: - Fixtures

    private func makeSyncedFixture() async throws -> SyncCoordinatorTestFixture {
        try await SyncCoordinatorTestFixture.make(
            directoryURL: directoryURL,
            localSave: SaveTestSupport.makeSave(modifiedAt: earlier, gold: 0),
            remoteSave: SaveTestSupport.makeRemote(modifiedAt: later, gold: 0)
        )
    }
}
