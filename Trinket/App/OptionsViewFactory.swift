import SwiftUI
import TrinketAppState
import TrinketContent

@MainActor
func makeOptionsView(appState: AppState) -> OptionsView {
    OptionsView(
        persistenceStatusMessage: { appState.persistenceStatusMessage },
        applyMusicVolumeLive: { volume, phase in
            appState.applyMusicVolumeLive(volume, scenePhase: phase)
        },
        playToggleSFX: { isEnabled, volume in
            appState.sfxPlayer.play(
                isEnabled ? SFXID.uiToggleOn : SFXID.uiToggleOff,
                volume: volume,
            )
        },
        resetGameplayProgress: appState.resetGameplayProgress,
        unlockAllContent: appState.unlockAllContent,
    )
}
