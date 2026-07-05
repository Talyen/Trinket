import TrinketPersistence
import XCTest

final class PlayerSaveSyncFactoryTests: XCTestCase {
    func testMissingCloudKitEntitlementsUsesLocalOnlySync() {
        var didCreateCloudSync = false

        let sync = PlayerSaveSyncFactory.makeSyncService(
            entitlementChecker: StubCloudKitEntitlementChecker(hasContainer: false),
            cloudSyncFactory: {
                didCreateCloudSync = true
                return StubPlayerSaveSync()
            }
        )

        XCTAssertTrue(sync is LocalOnlyPlayerSaveSync)
        XCTAssertFalse(didCreateCloudSync)
    }

    func testDisableCloudSyncFlagSkipsEntitlementCheck() {
        let entitlementChecker = SpyCloudKitEntitlementChecker(hasContainer: true)

        let sync = PlayerSaveSyncFactory.makeSyncService(
            configuration: PlayerSaveSyncConfiguration(disableCloudSync: true),
            entitlementChecker: entitlementChecker,
            cloudSyncFactory: { StubPlayerSaveSync() }
        )

        XCTAssertTrue(sync is LocalOnlyPlayerSaveSync)
        XCTAssertEqual(entitlementChecker.checkedIdentifiers, [])
    }

    func testResetStateFlagSkipsCloudSync() {
        let entitlementChecker = SpyCloudKitEntitlementChecker(hasContainer: true)

        let sync = PlayerSaveSyncFactory.makeSyncService(
            configuration: PlayerSaveSyncConfiguration(resetState: true),
            entitlementChecker: entitlementChecker,
            cloudSyncFactory: { StubPlayerSaveSync() }
        )

        XCTAssertTrue(sync is LocalOnlyPlayerSaveSync)
        XCTAssertEqual(entitlementChecker.checkedIdentifiers, [])
    }

    func testCloudKitEntitlementsUseCloudSyncFactory() {
        var didCreateCloudSync = false

        let sync = PlayerSaveSyncFactory.makeSyncService(
            entitlementChecker: StubCloudKitEntitlementChecker(hasContainer: true),
            cloudSyncFactory: {
                didCreateCloudSync = true
                return StubPlayerSaveSync()
            }
        )

        XCTAssertTrue(sync is StubPlayerSaveSync)
        XCTAssertTrue(didCreateCloudSync)
    }
}

private struct StubCloudKitEntitlementChecker: CloudKitEntitlementChecking {
    let hasContainer: Bool

    func hasCloudKitContainer(identifier _: String) -> Bool {
        hasContainer
    }
}

private final class SpyCloudKitEntitlementChecker: CloudKitEntitlementChecking {
    let hasContainer: Bool
    private(set) var checkedIdentifiers: [String] = []

    init(hasContainer: Bool) {
        self.hasContainer = hasContainer
    }

    func hasCloudKitContainer(identifier: String) -> Bool {
        checkedIdentifiers.append(identifier)
        return hasContainer
    }
}

private struct StubPlayerSaveSync: PlayerSaveSyncing {
    func accountStatus() async -> PlayerSaveAccountStatus {
        await Task.yield()
        return .available
    }

    func fetchRemoteSave() async throws -> RemotePlayerSave? {
        await Task.yield()
        return nil
    }

    func upload(_: PlayerSave, replacingRecordChangeTag _: String?) async throws -> String? {
        await Task.yield()
        return nil
    }

    func subscribeToChanges() async throws {
        await Task.yield()
    }
}
