import Foundation

public struct PlayerSaveSyncConfiguration: Sendable {
    public var disableCloudSync: Bool
    public var resetState: Bool

    public init(disableCloudSync: Bool = false, resetState: Bool = false) {
        self.disableCloudSync = disableCloudSync
        self.resetState = resetState
    }

    public func makeSyncService(
        entitlementChecker: any CloudKitEntitlementChecking = RuntimeCloudKitEntitlementChecker(),
        cloudSyncFactory: () -> any PlayerSaveSyncing = { CloudKitPlayerSaveSync() }
    ) -> any PlayerSaveSyncing {
        if disableCloudSync || resetState {
            return LocalOnlyPlayerSaveSync()
        }

        guard entitlementChecker.hasCloudKitContainer(
            identifier: CloudKitPlayerSaveSync.containerIdentifier
        ) else {
            return LocalOnlyPlayerSaveSync()
        }

        return cloudSyncFactory()
    }
}
