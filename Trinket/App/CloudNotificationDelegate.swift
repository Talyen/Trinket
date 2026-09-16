import CloudKit
import os
import TrinketAppState
import TrinketPersistence
import UIKit

private let cloudNotificationLogger = Logger(
    subsystem: PlayerSaveDefaults.loggingSubsystem,
    category: "CloudNotification",
)

/// Stays on the main actor because PlayerSaveStore is @MainActor-bound;
/// moving sync off-actor would require a larger persistence refactor.
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
              notification.containerIdentifier == PlayerSaveStore.cloudKitContainerIdentifier
        else { return .noData }
        guard let store, let sync = store.cloudSync else {
            cloudNotificationLogger.error("Cloud push ignored: no store or sync available.")
            return .noData
        }
        let generation = store.currentSave.sessionGeneration
        guard await sync.synchronize() else {
            cloudNotificationLogger.error("Cloud push sync failed.")
            return .failed
        }
        return Self.fetchResult(
            generationBefore: generation,
            generationAfter: store.currentSave.sessionGeneration,
        )
    }

    /// Pure fetch-result decision, extracted for tests: `.newData` only when
    /// sync actually advanced the save generation.
    static func fetchResult(generationBefore: UInt64, generationAfter: UInt64) -> UIBackgroundFetchResult {
        generationAfter == generationBefore ? .noData : .newData
    }
}
