import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var collectionPath: [CollectionRoute] = Self.initialCollectionPath()

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
                NavigationStack(path: $collectionPath) {
                    CollectionView(initialCombatantDetail: Self.initialCollectionCombatantDetail())
                        .navigationDestination(for: CollectionRoute.self) { route in
                            CollectionRouteDestination(route: route)
                        }
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

    private static func initialCollectionPath() -> [CollectionRoute] {
        switch AppEnvironment.shared.launchScreen {
        case .itemDetail(let id):
            return [.item(id)]
        case .heroDetail, .petDetail, .battle, .options, .none:
            return []
        }
    }

    private static func initialCollectionCombatantDetail() -> CombatantCollectionDetailSelection? {
        switch AppEnvironment.shared.launchScreen {
        case .heroDetail(let id):
            CombatantCollectionDetailSelection(kind: .hero, combatantID: id)
        case .petDetail(let id):
            CombatantCollectionDetailSelection(kind: .pet, combatantID: id)
        case .itemDetail, .battle, .options, .none:
            nil
        }
    }
}

private enum CollectionRoute: Hashable {
    case item(String)
}

private struct CollectionRouteDestination: View {
    @Environment(AppState.self) private var appState
    let route: CollectionRoute

    var body: some View {
        switch route {
        case .item(let id):
            itemDestination(id: id)
        }
    }

    @ViewBuilder
    private func itemDestination(id: String) -> some View {
        if let item = appState.inventory.current.items.first(where: { $0.id == id }) {
            ItemDetailView(item: item)
        } else {
            ContentUnavailableView("Item Not Found", systemImage: "questionmark.circle")
        }
    }

}
