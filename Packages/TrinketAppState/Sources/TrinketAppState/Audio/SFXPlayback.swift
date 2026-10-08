import Foundation
import TrinketContent

enum SFXCommand: Sendable {
    case play([String], volume: Double)
    case warm([String], voiceCount: Int)
    case warmCatalog(voiceCount: Int)
    case stop
    case release
}

/// Owns command policy, caches and round-robin allocation independently of the
/// audio framework. Foreground commands are submitted in order by SFXPlayer;
/// catalog warming can yield during decode and must honor resource invalidation.
actor SFXPlayback<Backend: SFXPlaybackBackend> {
    private final class VoicePool {
        let buffer: Backend.Buffer
        var voices: [Backend.Voice] = []
        var nextIndex = 0

        init(buffer: Backend.Buffer) {
            self.buffer = buffer
        }

        func next() -> Backend.Voice? {
            guard !voices.isEmpty else { return nil }
            let voice = voices[nextIndex % voices.count]
            nextIndex = (nextIndex + 1) % voices.count
            return voice
        }
    }

    private enum Resource {
        case loading(Task<Backend.Buffer?, Never>)
        case ready(VoicePool)
        case failed
    }

    private var backend: Backend
    private let load: @Sendable (SFXClip) async -> Backend.Buffer?
    private var resources: [String: Resource] = [:]
    private var catalogWarmTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init(
        backend: sending Backend,
        load: @escaping @Sendable (SFXClip) async -> Backend.Buffer? = { await Backend.load($0) },
    ) {
        self.backend = backend
        self.load = load
    }

    isolated deinit {
        catalogWarmTask?.cancel()
        for case let .loading(task) in resources.values {
            task.cancel()
        }
    }

    func execute(_ command: SFXCommand) async {
        switch command {
        case let .play(ids, volume):
            let volume = AudioSupport.clampedVolume(volume)
            guard volume > 0, !ids.isEmpty, await prepareAndStart(ids, voiceCount: 1) else { return }
            for id in ids {
                guard let clip = SFXCatalog.clipsByID[id],
                      case let .ready(pool) = resources[id], let voice = pool.next() else { continue }
                backend.play(voice, volume: AudioSupport.targetVolume(appVolume: volume, gain: clip.volumeGain))
            }
        case let .warm(ids, voiceCount): _ = await prepareAndStart(ids, voiceCount: voiceCount)
        case let .warmCatalog(voiceCount):
            catalogWarmTask?.cancel()
            catalogWarmTask = Task { [weak self] in
                _ = await self?.prepareAndStart(SFXCatalog.clips.map(\.id), voiceCount: voiceCount)
            }
        case .stop:
            invalidatePendingLoads()
            backend.stop()
        case .release:
            invalidatePendingLoads()
            backend.releaseResources()
            resources.removeAll()
        }
    }

    private func prepareAndStart(_ ids: [String], voiceCount: Int) async -> Bool {
        let startedGeneration = generation
        let voiceCount = max(1, voiceCount)
        for id in ids {
            guard !Task.isCancelled, generation == startedGeneration else { return false }
            guard let clip = SFXCatalog.clipsByID[id] else { continue }
            let pool: VoicePool
            switch resources[id] {
            case let .ready(existing): pool = existing
            case .failed: continue
            case .loading, nil:
                let task: Task<Backend.Buffer?, Never>
                if case let .loading(existing) = resources[id] {
                    task = existing
                } else {
                    let load = load
                    task = Task.detached(priority: .utility) { await load(clip) }
                    resources[id] = .loading(task)
                }
                let decoded = await task.value
                guard generation == startedGeneration, !Task.isCancelled else { return false }
                // A shared decode may already have completed in another warmup.
                // Grow that same pool so voices and its rotation never get replaced.
                if case let .ready(existing) = resources[id] {
                    pool = existing
                } else if let decoded {
                    pool = VoicePool(buffer: decoded)
                    resources[id] = .ready(pool)
                } else {
                    resources[id] = .failed
                    continue
                }
            }
            while pool.voices.count < voiceCount {
                pool.voices.append(backend.makeVoice(buffer: pool.buffer))
            }
        }
        return generation == startedGeneration && !Task.isCancelled && backend.start()
    }

    private func invalidatePendingLoads() {
        generation &+= 1
        catalogWarmTask?.cancel()
        catalogWarmTask = nil
        resources = resources.filter {
            guard case let .loading(task) = $0.value else { return true }
            task.cancel()
            return false
        }
    }
}
