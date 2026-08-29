import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(ShellSession.self) private var shellSession
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.scenePhase) private var scenePhase
    @State private var didAcknowledgePersistenceRecovery = false

    var body: some View {
        @Bindable var shellSession = shellSession

        Group {
            if playerSave.starterSelection.phase != .complete {
                StarterSelectionFlow(
                    initialSelection: playerSave.starterSelection,
                    confirmHero: appState.confirmStarterHero,
                    confirmCompanion: appState.completeStarterSelection
                )
                .transition(.opacity)
            } else {
                tabRoot(selection: $shellSession.selectedTab)
                    .transition(.opacity)
            }
        }
        .animation(TrinketMotion.Screen.crossfade, value: playerSave.starterSelection.phase)
        .trinketSensoryFeedback(
            .success,
            trigger: playerSave.starterSelection.phase == .complete,
            enabled: appState.options.hapticsEnabled
        )
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
            appState.refreshMusic(scenePhase: scenePhase)
        }
        .onChange(of: shellSession.selectedTab) { _, newTab in
            appState.refreshMusic(scenePhase: scenePhase)
            AppFramePacingSignposts.event(
                AppFramePacingSignposts.Name.tabSwitch,
                detail: "tab=\(newTab.rawValue)"
            )
        }
        .onChange(of: battle.activeBattle?.id) { _, newValue in
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
        .toolbarVisibility(
            battle.lifecyclePhase == .active ? .hidden : .visible,
            for: .tabBar
        )
    }
}
