import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

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
                    HomesteadView()
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
        .onAppear {
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            if appState.battle.activeBattle != nil {
                appState.battle.isPaused = newTab != .play
            }
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
            guard newValue != nil else {
                appState.battle.isPaused = false
                refreshMusicRoute(scenePhase: scenePhase)
                appState.musicPlayer.clearEncounterResumePositions()
                return
            }

            appState.battle.isPaused = appState.selectedTab != .play
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: appState.battle.preview?.id) { _, _ in
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: appState.options.musicVolume) { _, _ in
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            refreshMusicRoute(scenePhase: newPhase)
        }
    }

    private func refreshMusicRoute(scenePhase: ScenePhase) {
        let route = appState.musicDirector.route(
            selectedTab: appState.selectedTab,
            preview: appState.battle.preview,
            activeBattle: appState.battle.activeBattle,
            sceneIsActive: scenePhase == .active,
            musicVolume: appState.options.musicVolume
        )
        appState.musicPlayer.update(route: route, volume: appState.options.musicVolume)
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
