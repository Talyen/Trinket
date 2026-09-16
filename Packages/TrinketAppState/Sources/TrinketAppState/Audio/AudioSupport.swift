import AVFoundation
import Foundation
import os
import TrinketPersistence

/// Shared audio plumbing for `MusicPlayer` and `SFXPlayer`.
///
/// Single place for the logging subsystem, volume math, and the process-wide
/// ambient session configuration. Session setup is serialized and runs once;
/// retry happens only when a previous attempt failed.
enum AudioSupport {
    static let subsystem = PlayerSaveDefaults.loggingSubsystem

    static func logger(category: String = "Audio") -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    /// Clamps an app-level 0...1 volume to a playable `Float` gain.
    static func clampedVolume(_ volume: Double) -> Float {
        Float(max(0, min(volume, 1)))
    }

    /// Applies a catalog gain to an app volume, clamped to 0...1.
    static func targetVolume(appVolume: Float, gain: Double) -> Float {
        min(appVolume * Float(max(0, gain)), 1)
    }
}

enum AudioSession {
    // Concurrency-Safety: lock-guarded flag box; all access serializes on `lock`.
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var hasConfigured = false
    }

    private static let state = State()

    /// Configures the shared ambient session once. Safe to call from any
    /// isolation; concurrent callers serialize on a lock and only the first
    /// successful configuration sticks. Failures leave the flag clear so a
    /// later call retries.
    static func configureIfNeeded(logger: Logger) {
        state.lock.lock()
        let alreadyConfigured = state.hasConfigured
        state.lock.unlock()
        guard !alreadyConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            state.lock.lock()
            state.hasConfigured = true
            state.lock.unlock()
        } catch {
            logger.error(
                "Unable to configure audio session: \(error.localizedDescription, privacy: .public)",
            )
        }
    }
}
