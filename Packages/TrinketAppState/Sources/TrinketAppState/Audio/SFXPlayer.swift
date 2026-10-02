import Foundation

@MainActor
public final class SFXPlayer {
    private let playback = SFXPlayback(backend: SystemSFXPlaybackBackend())
    private let continuation: AsyncStream<SFXCommand>.Continuation?
    private var workerTask: Task<Void, Never>?

    public init(isDisabled: Bool) {
        if isDisabled {
            continuation = nil
            workerTask = nil
        } else {
            let (stream, continuation) = AsyncStream<SFXCommand>.makeStream()
            self.continuation = continuation
            let playback = playback
            workerTask = Task {
                for await command in stream {
                    guard !Task.isCancelled else { break }
                    await playback.execute(command)
                }
            }
        }
    }

    isolated deinit {
        workerTask?.cancel()
        continuation?.finish()
    }

    public func play(_ id: String, volume: Double) {
        playAll([id], volume: volume)
    }

    public func playAll(_ ids: [String], volume: Double) {
        guard continuation != nil, volume > 0, !ids.isEmpty else { return }
        enqueue(.play(ids, volume: volume))
    }

    public func warm(_ ids: [String], concurrentPlayerCount: Int) {
        enqueue(.warm(ids, voiceCount: concurrentPlayerCount))
    }

    public func warmAllCatalog(concurrentPlayerCount: Int) {
        enqueue(.warmCatalog(voiceCount: concurrentPlayerCount))
    }

    public func stopAll() {
        enqueue(.stop)
    }

    public func releaseResources() {
        enqueue(.release)
    }

    private func enqueue(_ command: SFXCommand) {
        continuation?.yield(command)
    }
}
