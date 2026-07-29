import AVFoundation
import Foundation
import os
import TrinketFeatureSupport

enum AudioLogging {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.ryanmcintire.Trinket"
}

/// Shared ambient `AVAudioSession` setup for music and SFX players.
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
                "Unable to configure audio session: \(error.localizedDescription, privacy: .public)"
            )
        }
        configured = true
    }
}
