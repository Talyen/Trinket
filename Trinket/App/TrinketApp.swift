import SwiftUI
#if canImport(UIKit)
import TrinketPersistence
import UIKit
#endif

final class CloudSyncAppDelegate: NSObject, UIApplicationDelegate {
    var syncCoordinator: PlayerSaveSyncCoordinator?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification _: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let syncCoordinator else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let hadRemoteChanges = await syncCoordinator.reconcileFromRemoteNotification()
            completionHandler(hadRemoteChanges ? .newData : .noData)
        }
    }
}

@main
struct TrinketApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(CloudSyncAppDelegate.self) private var appDelegate
    #endif
    @State private var appState = AppState()

    init() {
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    #if canImport(UIKit)
                    appDelegate.syncCoordinator = appState.syncCoordinator
                    #endif
                    await appState.syncCoordinator.activateSession(subscribeToChanges: true)
                }
        }
    }

    private func configureGlobalAppearance() {
        #if canImport(UIKit)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        #endif
    }
}
