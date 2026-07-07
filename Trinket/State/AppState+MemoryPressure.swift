#if canImport(UIKit)
import UIKit
#endif
import Foundation

extension AppState {
    func installMemoryPressureHandling() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.trimMemoryFootprint()
            }
        }
        #endif
    }

    func trimMemoryFootprint() {
        battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.trimMemoryFootprint()
    }
}
