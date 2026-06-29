import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    init() {
        let env = AppEnvironment.shared
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        }
    }

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                PlayView()
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView()
                }
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    PlaceholderTabView(title: "Homestead")
                }
            }

            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView()
                }
            }
        }
        .preferredColorScheme(appState.options.theme.colorScheme)
        .onChange(of: appState.selectedTab) { _, newTab in
            guard appState.battle.activeBattle != nil else { return }
            appState.battle.isPaused = newTab != .play
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
            guard newValue != nil else {
                appState.battle.isPaused = false
                return
            }

            appState.battle.isPaused = appState.selectedTab != .play
        }
    }
}
