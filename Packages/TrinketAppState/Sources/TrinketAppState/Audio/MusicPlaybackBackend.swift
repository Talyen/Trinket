import AVFoundation
import Foundation
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
        let logger = AudioSupport.logger()
        guard let url = AudioSupport.mediaURL(
            resourceName: track.resourceName, fileExtension: track.fileExtension, subdirectory: "Music",
        ) else {
            logger.warning("Missing music resource: \(track.resourceName, privacy: .public).\(track.fileExtension, privacy: .public)")
            return nil
        }
        let loaded = await Task.detached(priority: .utility) { () -> LoadedMusicPlayer? in
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return LoadedMusicPlayer(player: player)
            } catch {
                return nil
            }
        }.value
        guard let loaded else {
            logger.error("Unable to load music resource \(track.resourceName, privacy: .public).\(track.fileExtension, privacy: .public)")
            return nil
        }
        return SystemMusicPlaybackVoice(player: loaded.player)
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

    init(player: AVAudioPlayer) {
        self.player = player
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
        player.play()
    }

    func stop() {
        player.stop()
    }
}

// Concurrency-Safety: the detached decoder exclusively owns the player until
// returning this box; all subsequent access is through the main-actor voice.
private final class LoadedMusicPlayer: @unchecked Sendable {
    let player: AVAudioPlayer

    init(player: AVAudioPlayer) {
        self.player = player
    }
}
