import SwiftUI

@Observable
final class AppState {
    var selectedTab: AppTab = .play
    var roster = PlayerRosterStore()
    var inventory = PlayerInventoryStore()
    var options = OptionsStore()
    var battle = BattleSession()

    init() {
        let env = AppEnvironment.shared
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
            roster = PlayerRosterStore()
            inventory = PlayerInventoryStore()
            options = OptionsStore()
        }
        if let tab = env.launchTab {
            selectedTab = tab
        }
    }
}
