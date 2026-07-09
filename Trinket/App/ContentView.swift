import SwiftUI
import TrinketDesignSystem

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var localSelectedTab: AppTab = .play

    var body: some View {
        tabRoot(selection: $localSelectedTab)
            .preferredColorScheme(appState.options.appearance.colorScheme)
            .onAppear {
                localSelectedTab = appState.selectedTab
                appState.reconcileShellState(.appeared, scenePhase: scenePhase)
            }
            .onChange(of: localSelectedTab) { _, newTab in
                appState.selectedTab = newTab
                if newTab == .homestead {
                    appState.acknowledgeHomesteadActionablesIfNeeded()
                }
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                localSelectedTab = newTab
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
                    CollectionView()
                }
            }
            .badge(appState.collectionBadge.map { Text("\($0)") })

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    HomesteadView()
                }
            }
            .badge(appState.homesteadBadge.map { Text("\($0)") })

            Tab(AppTab.options.displayName, systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView()
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
