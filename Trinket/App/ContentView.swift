import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(BattleSession.self) private var battle
    @Environment(\.scenePhase) private var scenePhase
    @State private var localSelectedTab: AppTab = .play
    @State private var didAcknowledgePersistenceRecovery = false

    var body: some View {
        // Bare PlayView during battle removes the tab bar from the hierarchy.
        Group {
            if battle.lifecyclePhase == .active {
                PlayView()
                    .transition(.opacity)
            } else {
                tabRoot(selection: battleLockedSelection)
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: battle.activeBattle?.id)
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
            if battle.lifecyclePhase == .active {
                localSelectedTab = .play
                appState.selectedTab = .play
            } else {
                localSelectedTab = appState.selectedTab
            }
            appState.reconcileShellState(.appeared, scenePhase: scenePhase)
        }
        .onChange(of: localSelectedTab) { _, newTab in
            guard battle.lifecyclePhase != .active || newTab == .play else {
                localSelectedTab = .play
                return
            }
            appState.selectedTab = newTab
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            guard battle.lifecyclePhase != .active || newTab == .play else {
                appState.selectedTab = .play
                localSelectedTab = .play
                return
            }
            localSelectedTab = newTab
            appState.reconcileShellState(.tabChanged, scenePhase: scenePhase)
        }
        .onChange(of: battle.activeBattle?.id) { _, newValue in
            if newValue != nil {
                localSelectedTab = .play
                appState.selectedTab = .play
            }
            appState.reconcileShellState(
                .activeBattleChanged(started: newValue != nil),
                scenePhase: scenePhase
            )
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
            }

            Tab(AppTab.collection.displayName, systemImage: AppTab.collection.symbolName, value: AppTab.collection) {
                NavigationStack {
                    CollectionView {
                        appState.consumePendingCollectionPresentation()
                    }
                }
            }

            Tab(AppTab.homestead.displayName, systemImage: AppTab.homestead.symbolName, value: AppTab.homestead) {
                NavigationStack {
                    HomesteadView()
                }
            }

            Tab(AppTab.options.displayName, systemImage: AppTab.options.symbolName, value: AppTab.options) {
                NavigationStack {
                    OptionsView(
                        persistenceStatusMessage: { appState.persistenceStatusMessage },
                        applyMusicVolumeLive: { volume, phase in
                            appState.applyMusicVolumeLive(volume, scenePhase: phase)
                        },
                        playToggleSFX: { isEnabled, volume in
                            appState.sfxPlayer.play(
                                isEnabled ? SFXID.uiToggleOn : SFXID.uiToggleOff,
                                volume: volume
                            )
                        },
                        resetGameplayProgress: appState.resetGameplayProgress,
                        unlockAllContent: appState.unlockAllContent
                    )
                }
            }
        }
        .onChange(of: localSelectedTab) { _, newTab in
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.tabSwitch,
                detail: "tab=\(newTab.rawValue)"
            )
        }
    }

    private var battleLockedSelection: Binding<AppTab> {
        Binding(
            get: { localSelectedTab },
            set: { newTab in
                guard battle.lifecyclePhase != .active || newTab == .play else { return }
                localSelectedTab = newTab
            }
        )
    }
}
