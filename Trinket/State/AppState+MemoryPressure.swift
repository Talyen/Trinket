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
                self?.handleMemoryPressure()
            }
        }
        #endif
    }

    func handleMemoryPressure() {
        battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.trimMemoryFootprint()
    }

    func trimMemoryFootprintForBackground() {
        battle.trimMemoryFootprint(releaseBattleLog: true)
        musicPlayer.trimMemoryFootprint()
    }
}
