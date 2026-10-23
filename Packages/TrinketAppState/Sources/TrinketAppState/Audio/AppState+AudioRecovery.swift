import SwiftUI

public extension AppState {
    /// Called by direct player interactions, never by automatic battle feedback
    /// or scene activation. Media-services recovery must wait for user intent.
    func resumeAudioAfterMediaServicesReset(scenePhase: ScenePhase) {
        guard scenePhase == .active,
              musicPlayer.needsMediaServicesRecovery || sfxPlayer.needsMediaServicesRecovery else { return }
        musicPlayer.resumeAfterMediaServicesReset()
        sfxPlayer.resumeAfterMediaServicesReset()
        refreshMusic(scenePhase: scenePhase)
    }
}
