import SwiftUI
import TrinketAppState
import TrinketContent
import TrinketDesignSystem

struct HiddenTabPrewarm: View {
    let appState: AppState

    var body: some View {
        ZStack {
            NavigationStack {
                CollectionView()
            }
            NavigationStack {
                HomesteadView()
            }
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
        .opacity(0.001)
        .scaleEffect(0.01)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
