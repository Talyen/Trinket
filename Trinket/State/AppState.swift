import SwiftUI

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab
    var roster = PlayerRosterStore()
    var inventory = PlayerInventoryStore()
    var options = OptionsStore()
    var battle = BattleSession()

    init() {
        let env = AppEnvironment.shared
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        }
        selectedTab = env.launchTab ?? .play
    }
}
