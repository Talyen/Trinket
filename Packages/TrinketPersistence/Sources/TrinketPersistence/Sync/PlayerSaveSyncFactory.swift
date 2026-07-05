import Foundation

public struct PlayerSaveSyncConfiguration: Sendable {
    public var disableCloudSync: Bool
    public var resetState: Bool

    public init(disableCloudSync: Bool = false, resetState: Bool = false) {
        self.disableCloudSync = disableCloudSync
        self.resetState = resetState
    }
}

public enum PlayerSaveSyncFactory {
    public static func makeSyncService(
        configuration: PlayerSaveSyncConfiguration = PlayerSaveSyncConfiguration(),
        entitlementChecker: any CloudKitEntitlementChecking = RuntimeCloudKitEntitlementChecker(),
        cloudSyncFactory: () -> any PlayerSaveSyncing = { CloudKitPlayerSaveSync() }
    ) -> any PlayerSaveSyncing {
        if configuration.disableCloudSync || configuration.resetState {
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
