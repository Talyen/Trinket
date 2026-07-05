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
        .preferredColorScheme(appState.options.appearance.colorScheme)
        .onAppear {
            appState.handleShellAppear(scenePhase: scenePhase)
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.handleSelectedTabChange(newTab, scenePhase: scenePhase)
        }
        .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
            if newValue == nil {
                appState.handleActiveBattleEnded(scenePhase: scenePhase)
            } else {
                appState.handleActiveBattleStarted(scenePhase: scenePhase)
            }
        }
        .onChange(of: appState.battle.preview?.id) { _, _ in
            appState.handleMusicPreviewChange(scenePhase: scenePhase)
        }
        .onChange(of: appState.options.musicVolume) { _, _ in
            appState.handleMusicVolumeChange(scenePhase: scenePhase)
        }
        .onChange(of: scenePhase) { _, newPhase in
            appState.handleScenePhaseChange(newPhase)
        }
    }
}
