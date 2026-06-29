import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab
    @State private var activeBattle: ActiveBattleConfiguration?
    @State private var rosterState = PlayerRosterState.initial
    @State private var inventoryState = PlayerInventoryState.initial
    @State private var isBattlePaused = false
    @AppStorage("options.theme") private var theme = TrinketDesign.AppTheme.system

    init() {
        let env = AppEnvironment.shared
        if env.resetState {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        }
        _selectedTab = State(initialValue: env.launchTab ?? .play)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                PlayView(
                    rosterState: $rosterState,
                    inventoryState: $inventoryState,
                    activeBattle: $activeBattle,
                    isBattlePaused: $isBattlePaused
                )
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView(
                        rosterState: $rosterState,
                        inventoryState: $inventoryState
                    )
                }
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    PlaceholderTabView(title: "Homestead")
                }
            }

            Tab(value: AppTab.search, role: .search) {
                NavigationStack {
                    SearchView(
                        rosterState: $rosterState,
                        inventoryState: $inventoryState
                    )
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .onChange(of: selectedTab) { _, newTab in
            guard activeBattle != nil else { return }
            isBattlePaused = newTab != .play
        }
        .onChange(of: activeBattle?.id) { _, newValue in
            guard newValue != nil else {
                isBattlePaused = false
                return
            }

            isBattlePaused = selectedTab != .play
        }
    }
}
