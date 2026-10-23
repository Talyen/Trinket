import Foundation
import TrinketCore

@MainActor
public final class SFXPlayer {
    private let execute: @Sendable (SFXCommand) async -> Void
    private var continuation: AsyncStream<SFXCommand>.Continuation?
    private var workerTask: Task<Void, Never>?
    private var invalidationTask: Task<Void, Never>?
    private var mediaServicesResetObserver: MainActorCleanup?
    private(set) var needsMediaServicesRecovery = false

    public convenience init(isDisabled: Bool) {
        let playback = SFXPlayback(backend: SystemSFXPlaybackBackend())
        self.init(isDisabled: isDisabled) { await playback.execute($0) }
    }

    init(
        isDisabled: Bool = false,
        notificationCenter: NotificationCenter = .default,
        execute: @escaping @Sendable (SFXCommand) async -> Void,
    ) {
        self.execute = execute
        if !isDisabled {
            startWorker()
            mediaServicesResetObserver = AudioSupport.observeMediaServicesReset(in: notificationCenter) { [weak self] in
                self?.needsMediaServicesRecovery = true
                self?.releaseResources()
            }
        }
    }

    deinit {
        workerTask?.cancel()
        continuation?.finish()
        guard continuation != nil else { return }
        let invalidation = invalidationTask
        let execute = execute
        // The audio actor owns catalog warming independently of the worker.
        // Retire it without waiting for a suspended foreground decode to finish.
        Task {
            await invalidation?.value
            await execute(.shutdown)
        }
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
        invalidate(.stop)
    }

    public func releaseResources() {
        invalidate(.release)
    }

    func resumeAfterMediaServicesReset() {
        needsMediaServicesRecovery = false
    }

    private func enqueue(_ command: SFXCommand) {
        guard !needsMediaServicesRecovery else { return }
        continuation?.yield(command)
    }

    private func invalidate(_ command: SFXCommand) {
        guard continuation != nil else { return }
        // A decode can suspend the worker indefinitely. Stop must reach the audio
        // actor without waiting for that decode, and older queued sounds must die.
        workerTask?.cancel()
        continuation?.finish()
        let previousInvalidation = invalidationTask
        let execute = execute
        invalidationTask = Task {
            await previousInvalidation?.value
            await execute(command)
        }
        startWorker()
    }

    private func startWorker() {
        let (stream, continuation) = AsyncStream<SFXCommand>.makeStream()
        self.continuation = continuation
        let invalidation = invalidationTask
        let execute = execute
        workerTask = Task {
            await invalidation?.value
            for await command in stream {
                guard !Task.isCancelled else { break }
                await execute(command)
            }
        }
    }
}
