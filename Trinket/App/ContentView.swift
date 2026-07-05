import SwiftUI
import TrinketDesignSystem

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(AppTab.play.displayName, systemImage: AppTab.play.symbolName, value: AppTab.play) {
                NavigationStack {
                    PlayView()
                }
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView(
                        initialCombatantDetail: appState.initialCollectionCombatantDetail,
                        initialItemID: appState.initialCollectionItemID
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
        .environment(\.trinketTheme, appState.options.theme)
        .preferredColorScheme(appState.options.appearance.colorScheme)
        .tint(appState.options.theme.palette.accent)
        .onAppear {
            syncBattlePauseForCurrentTab()
            refreshMusicRoute(scenePhase: scenePhase)
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.sessionState.selectedTab = newTab
            if appState.battle.activeBattle != nil {
                // Leaving Play pauses combat; returning stays paused until the player resumes.
                appState.battle.isPaused = true
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
            if newPhase != .active, appState.battle.activeBattle != nil {
                appState.battle.isPaused = true
            }
            refreshMusicRoute(scenePhase: newPhase)
            if newPhase == .inactive || newPhase == .background {
                appState.playerSave.flushPendingPersistIfNeeded()
            }
            if newPhase == .background {
                Task {
                    await appState.syncCoordinator.checkpointUploadIfNeeded()
                }
            } else if newPhase == .active {
                Task {
                    await appState.syncCoordinator.reconcileForegroundIfSafe(
                        hasActiveBattle: appState.battle.activeBattle != nil
                    )
                }
            }
        }
    }

    private func syncBattlePauseForCurrentTab() {
        guard appState.battle.activeBattle != nil else { return }
        if appState.selectedTab != .play {
            appState.battle.isPaused = true
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
}
