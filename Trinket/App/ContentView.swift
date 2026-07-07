import SwiftUI
import TrinketDesignSystem

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var state = appState

        tabRoot(selection: $state.selectedTab)
            .preferredColorScheme(appState.options.appearance.colorScheme)
            .onAppear {
                appState.reconcileShellState(.appeared, scenePhase: scenePhase)
            }
            .onChange(of: appState.selectedTab) { _, _ in
                appState.reconcileShellState(.tabChanged, scenePhase: scenePhase)
            }
            .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
                appState.reconcileShellState(
                    .activeBattleChanged(started: newValue != nil),
                    scenePhase: scenePhase
                )
            }
            .onChange(of: appState.battle.preview?.id) { _, _ in
                appState.refreshMusic(scenePhase: scenePhase)
            }
            .onChange(of: appState.options.musicVolume) { _, _ in
                appState.refreshMusic(scenePhase: scenePhase)
            }
            .onChange(of: scenePhase) { _, newPhase in
                appState.reconcileShellState(.scenePhaseChanged, scenePhase: newPhase)
            }
    }

    private func tabRoot(selection: Binding<AppTab>) -> some View {
        TabView(selection: selection) {
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
    }
}
