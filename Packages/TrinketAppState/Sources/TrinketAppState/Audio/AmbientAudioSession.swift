import AVFoundation
import Foundation
import os
import TrinketPersistence

enum AudioLogging {
    static let subsystem = PlayerSaveDefaults.loggingSubsystem
}

enum AmbientAudioSession {
    @MainActor
    static func configureIfNeeded(configured: inout Bool, logger: Logger) {
        guard !configured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.error(
                "Unable to configure audio session: \(error.localizedDescription, privacy: .public)",
            )
        }
        configured = true
    }
}
