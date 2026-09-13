import CloudKit
import TrinketAppState
import TrinketPersistence
import UIKit

@MainActor
final class CloudNotificationDelegate: NSObject, UIApplicationDelegate {
    weak var store: PlayerSaveStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
    ) -> Bool {
        if !AppEnvironment.shared.disableCloudSync {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    ) async -> UIBackgroundFetchResult {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.containerIdentifier == PlayerSaveStore.cloudKitContainerIdentifier,
              let store, let sync = store.cloudSync else { return .noData }
        let generation = store.currentSave.sessionGeneration
        guard await sync.synchronize() else { return .failed }
        return store.currentSave.sessionGeneration == generation ? .noData : .newData
    }
}
