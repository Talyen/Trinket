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
    private struct VoicePool {
        var voices: [Backend.Voice] = []
        var nextIndex = 0

        mutating func next() -> Backend.Voice? {
            guard !voices.isEmpty else { return nil }
            let voice = voices[nextIndex % voices.count]
            nextIndex = (nextIndex + 1) % voices.count
            return voice
        }
    }

    private var backend: Backend
    private let load: @Sendable (SFXClip) async -> Backend.Buffer?
    private var pools: [String: VoicePool] = [:]
    private var buffers: [String: Backend.Buffer] = [:]
    private var failedIDs: Set<String> = []
    private var loads: [String: Task<Backend.Buffer?, Never>] = [:]
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
        for task in loads.values {
            task.cancel()
        }
    }

    func execute(_ command: SFXCommand) async {
        switch command {
        case let .play(ids, volume): await play(ids, volume: volume)
        case let .warm(ids, voiceCount): await warm(ids, voiceCount: voiceCount)
        case let .warmCatalog(voiceCount):
            catalogWarmTask?.cancel()
            catalogWarmTask = Task { [weak self] in
                await self?.warm(SFXCatalog.clips.map(\.id), voiceCount: voiceCount)
            }
        case .stop: stop()
        case .release:
            stop()
            backend.releaseResources()
            pools.removeAll()
            buffers.removeAll()
            failedIDs.removeAll()
        }
    }

    private func play(_ ids: [String], volume: Double) async {
        let volume = AudioSupport.clampedVolume(volume)
        guard volume > 0, !ids.isEmpty else { return }
        let startedGeneration = generation
        await prepare(ids, voiceCount: 1)
        guard generation == startedGeneration, !Task.isCancelled, backend.start() else { return }
        for id in ids {
            guard let clip = SFXCatalog.clipsByID[id], let voice = pools[id]?.next() else { continue }
            backend.play(voice, volume: AudioSupport.targetVolume(appVolume: volume, gain: clip.volumeGain))
        }
    }

    private func warm(_ ids: [String], voiceCount: Int) async {
        let startedGeneration = generation
        await prepare(ids, voiceCount: max(1, voiceCount))
        guard generation == startedGeneration, !Task.isCancelled else { return }
        _ = backend.start()
    }

    private func prepare(_ ids: [String], voiceCount: Int) async {
        let startedGeneration = generation
        for id in ids {
            guard !Task.isCancelled, generation == startedGeneration else { return }
            guard (pools[id]?.voices.count ?? 0) < voiceCount,
                  !failedIDs.contains(id), let clip = SFXCatalog.clipsByID[id] else { continue }
            let buffer: Backend.Buffer
            if let cached = buffers[id] {
                buffer = cached
            } else {
                let task: Task<Backend.Buffer?, Never>
                if let existing = loads[id] {
                    task = existing
                } else {
                    let load = load
                    task = Task.detached(priority: .utility) { await load(clip) }
                    loads[id] = task
                }
                let decoded = await task.value
                guard generation == startedGeneration, !Task.isCancelled else { return }
                loads[id] = nil
                // Another warm may have filled this pool while decoding. Reuse
                // its buffer and grow from the latest pool, never an old copy.
                guard let resolved = buffers[id] ?? decoded else {
                    failedIDs.insert(id)
                    continue
                }
                buffer = resolved
                buffers[id] = buffer
            }
            var pool = pools[id, default: VoicePool()]
            while pool.voices.count < voiceCount {
                pool.voices.append(backend.makeVoice(buffer: buffer))
            }
            pools[id] = pool
        }
    }

    private func stop() {
        generation &+= 1
        catalogWarmTask?.cancel()
        catalogWarmTask = nil
        for task in loads.values {
            task.cancel()
        }
        loads.removeAll()
        backend.stop()
    }
}
