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
        selectedTab = env.launchTab ?? Self.defaultTab(for: env.launchScreen)
    }

    private static func defaultTab(for launchScreen: LaunchScreen?) -> AppTab {
        switch launchScreen {
        case .heroDetail, .petDetail, .itemDetail:
            return .collection
        case .battle:
            return .play
        case .options, .none:
            return .play
        }
    }
}
