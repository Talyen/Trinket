import SwiftUI
import TrinketDesignSystem

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var localSelectedTab: AppTab = .play
    @State private var didAcknowledgePersistenceRecovery = false

    var body: some View {
        tabRoot(selection: battleLockedSelection)
            .tint(TrinketDesign.Colors.accent)
            .preferredColorScheme(.dark)
            .alert(
                "Progress Storage Issue",
                isPresented: Binding(
                    get: {
                        appState.requiresPersistenceRecoveryAcknowledgement
                            && !didAcknowledgePersistenceRecovery
                    },
                    set: { isPresented in
                        if !isPresented {
                            didAcknowledgePersistenceRecovery = true
                        }
                    }
                )
            ) {
                Button("Continue") {
                    didAcknowledgePersistenceRecovery = true
                }
            } message: {
                Text(
                    appState.persistenceStatusMessage
                        ?? "Saved progress could not be opened normally. Check Options → Progress Status."
                )
            }
            .onAppear {
                if appState.battle.activeBattle != nil {
                    localSelectedTab = .play
                    appState.selectedTab = .play
                } else {
                    localSelectedTab = appState.selectedTab
                }
                appState.reconcileShellState(.appeared, scenePhase: scenePhase)
            }
            .onChange(of: localSelectedTab) { _, newTab in
                guard appState.battle.activeBattle == nil || newTab == .play else {
                    localSelectedTab = .play
                    return
                }
                appState.selectedTab = newTab
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                guard appState.battle.activeBattle == nil || newTab == .play else {
                    appState.selectedTab = .play
                    localSelectedTab = .play
                    return
                }
                localSelectedTab = newTab
                appState.reconcileShellState(.tabChanged, scenePhase: scenePhase)
            }
            .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
                if newValue != nil {
                    localSelectedTab = .play
                    appState.selectedTab = .play
                }
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
                PlayView()
                    .battleTabBarVisibility(appState.battle.activeBattle != nil)
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView()
                }
                .battleTabBarVisibility(appState.battle.activeBattle != nil)
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    HomesteadView()
                }
                .battleTabBarVisibility(appState.battle.activeBattle != nil)
            }

            Tab(AppTab.options.displayName, systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView()
                }
                .battleTabBarVisibility(appState.battle.activeBattle != nil)
            }
        }
    }

    private var battleLockedSelection: Binding<AppTab> {
        Binding(
            get: { localSelectedTab },
            set: { newTab in
                guard appState.battle.activeBattle == nil || newTab == .play else { return }
                localSelectedTab = newTab
            }
        )
    }
}

private extension View {
    func battleTabBarVisibility(_ isBattleActive: Bool) -> some View {
        toolbarVisibility(isBattleActive ? .hidden : .automatic, for: .tabBar)
    }
}
