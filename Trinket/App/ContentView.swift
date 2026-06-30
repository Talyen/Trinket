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
                    CollectionView(
                        initialCombatantDetail: Self.initialCollectionCombatantDetail(),
                        initialItemID: Self.initialCollectionItemID()
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
                    SearchView()
                }
            }

            Tab(AppTab.options.displayName, systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView()
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

    private static func initialCollectionCombatantDetail() -> CombatantCollectionDetailSelection? {
        switch AppEnvironment.shared.launchScreen {
        case let .heroDetail(id):
            CombatantCollectionDetailSelection(kind: .hero, combatantID: id)
        case let .petDetail(id):
            CombatantCollectionDetailSelection(kind: .pet, combatantID: id)
        case .itemDetail, .battle, .options, .none:
            nil
        }
    }

    private static func initialCollectionItemID() -> String? {
        switch AppEnvironment.shared.launchScreen {
        case let .itemDetail(id):
            id
        case .heroDetail, .petDetail, .battle, .options, .none:
            nil
        }
    }
}
