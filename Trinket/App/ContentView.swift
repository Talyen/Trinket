import SwiftUI
import TrinketDesignSystem

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var collectionPath = NavigationPath()

    var body: some View {
        @Bindable var state = appState

        tabRoot(selection: $state.selectedTab)
            .preferredColorScheme(appState.options.appearance.colorScheme)
            .onAppear {
                appState.shellDidAppear(scenePhase: scenePhase)
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                appState.shellDidChangeTab(to: newTab, scenePhase: scenePhase)
            }
            .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
                appState.shellDidChangeActiveBattle(started: newValue != nil, scenePhase: scenePhase)
            }
            .onChange(of: appState.battle.preview?.id) { _, _ in
                appState.refreshMusic(scenePhase: scenePhase)
            }
            .onChange(of: appState.options.musicVolume) { _, _ in
                appState.refreshMusic(scenePhase: scenePhase)
            }
            .onChange(of: scenePhase) { _, newPhase in
                appState.shellDidChangeScenePhase(newPhase)
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
                NavigationStack(path: $collectionPath) {
                    CollectionView(
                        initialCombatantDetail: appState.initialCollectionCombatantDetail,
                        initialItemID: appState.initialCollectionItemID,
                        collectionPath: $collectionPath
                    )
                }
            }
            .badge(appState.collectionBadge.map { Text("\($0)") })

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    HomesteadView()
                }
            }
            .badge(appState.homesteadBadge.map { Text($0) })

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
