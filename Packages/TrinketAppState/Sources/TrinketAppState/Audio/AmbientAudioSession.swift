import Foundation
import os

enum AudioLogging {
    static let subsystem = AudioSupport.subsystem
}

enum AmbientAudioSession {
    static func configureIfNeeded(configured: inout Bool, logger: Logger) {
        guard !configured else { return }
        AudioSession.configureIfNeeded(logger: logger)
        // Mirror the legacy per-player flag so existing call sites keep their
        // shape; the process-wide flag inside AudioSession owns retry semantics.
        configured = true
    }
}
