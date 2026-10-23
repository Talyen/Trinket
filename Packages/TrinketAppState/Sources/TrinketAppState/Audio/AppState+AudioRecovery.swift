import SwiftUI

public extension AppState {
    var needsMediaServicesRecovery: Bool {
        musicPlayer.needsMediaServicesRecovery || sfxPlayer.needsMediaServicesRecovery
    }

    /// Called by direct player interactions, never by automatic battle feedback
    /// or scene activation. Media-services recovery must wait for user intent.
    func resumeAudioAfterMediaServicesReset(scenePhase: ScenePhase) {
        guard scenePhase == .active, needsMediaServicesRecovery else { return }
        musicPlayer.resumeAfterMediaServicesReset()
        sfxPlayer.resumeAfterMediaServicesReset()
        refreshMusic(scenePhase: scenePhase)
    }
}
