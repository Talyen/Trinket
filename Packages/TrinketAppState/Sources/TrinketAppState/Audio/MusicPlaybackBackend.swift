import AVFoundation
import Foundation
import os
import TrinketContent

@MainActor
protocol MusicPlaybackVoice: AnyObject {
    var volume: Float { get set }
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    var numberOfLoops: Int { get set }
    func start()
    func stop()
}

@MainActor
protocol MusicPlaybackBackend {
    func load(_ track: TrinketContent.MusicTrack) async -> (any MusicPlaybackVoice)?
    func activateSession()
    func waitForFadeStep(_ duration: Duration) async throws
}

struct SystemMusicPlaybackBackend: MusicPlaybackBackend {
    func load(_ track: TrinketContent.MusicTrack) async -> (any MusicPlaybackVoice)? {
        guard !Task.isCancelled else { return nil }
        let logger = AudioSupport.logger()
        guard let url = AudioSupport.mediaURL(
            resourceName: track.resourceName, fileExtension: track.fileExtension, subdirectory: "Music",
        ) else {
            #if DEBUG
            AudioCoverageDiagnostics.failed()
            #endif
            logger.warning("Missing music resource: \(track.resourceName, privacy: .public).\(track.fileExtension, privacy: .public)")
            return nil
        }
        let loaded = await Self.decode(url: url)
        guard !Task.isCancelled else { return nil }
        guard let loaded else {
            #if DEBUG
            AudioCoverageDiagnostics.failed()
            #endif
            logger.error("Unable to load music resource \(track.resourceName, privacy: .public).\(track.fileExtension, privacy: .public)")
            return nil
        }
        return SystemMusicPlaybackVoice(player: loaded.player, trackID: track.id)
    }

    @concurrent
    private nonisolated static func decode(url: URL) async -> LoadedMusicPlayer? {
        guard !Task.isCancelled else { return nil }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            guard !Task.isCancelled else { return nil }
            player.prepareToPlay()
            guard !Task.isCancelled else { return nil }
            return LoadedMusicPlayer(player: player)
        } catch {
            return nil
        }
    }

    func activateSession() {
        AudioSession.configureIfNeeded(logger: AudioSupport.logger())
    }

    func waitForFadeStep(_ duration: Duration) async throws {
        try await SuspendingClock().sleep(for: duration, tolerance: .milliseconds(20))
    }
}

@MainActor
private final class SystemMusicPlaybackVoice: MusicPlaybackVoice {
    private let player: AVAudioPlayer

    #if DEBUG
    private let diagnosticID = UUID()
    private let trackID: String
    #endif

    init(player: AVAudioPlayer, trackID: String) {
        self.player = player
        #if DEBUG
        self.trackID = trackID
        #endif
    }

    var volume: Float {
        get { player.volume }
        set { player.volume = newValue }
    }

    var currentTime: TimeInterval {
        get { player.currentTime }
        set { player.currentTime = newValue }
    }

    var duration: TimeInterval {
        player.duration
    }

    var isPlaying: Bool {
        player.isPlaying
    }

    var numberOfLoops: Int {
        get { player.numberOfLoops }
        set { player.numberOfLoops = newValue }
    }

    func start() {
        #if DEBUG
        let started = player.play()
        if started {
            AudioCoverageDiagnostics.musicStarted(id: diagnosticID, track: trackID)
        } else {
            AudioCoverageDiagnostics.failed()
        }
        #else
        player.play()
        #endif
    }

    func stop() {
        player.stop()
        #if DEBUG
        AudioCoverageDiagnostics.musicStopped(id: diagnosticID)
        #endif
    }
}

// Concurrency-Safety: the concurrent decoder exclusively owns the player until
// returning this box; all subsequent access is through the main-actor voice.
private final class LoadedMusicPlayer: @unchecked Sendable {
    let player: AVAudioPlayer

    init(player: AVAudioPlayer) {
        self.player = player
    }
}
