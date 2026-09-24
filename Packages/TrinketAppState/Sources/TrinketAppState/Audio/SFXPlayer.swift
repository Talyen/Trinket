import AVFoundation
import Foundation
import os
import TrinketContent

@MainActor
public final class SFXPlayer {
    private let isDisabled: Bool
    private let playback = SFXPlayback()
    private let continuation: AsyncStream<@Sendable (isolated SFXPlayback) async -> Void>.Continuation?
    private var workerTask: Task<Void, Never>?

    public init(isDisabled: Bool) {
        self.isDisabled = isDisabled
        if isDisabled {
            continuation = nil
            workerTask = nil
        } else {
            var streamContinuation: AsyncStream<@Sendable (isolated SFXPlayback) async -> Void>.Continuation?
            let stream = AsyncStream<@Sendable (isolated SFXPlayback) async -> Void> { cont in
                streamContinuation = cont
            }
            continuation = streamContinuation
            let playback = playback
            workerTask = Task {
                for await operation in stream {
                    guard !Task.isCancelled else { break }
                    await operation(playback)
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
        guard !isDisabled, volume > 0, !ids.isEmpty else { return }
        enqueue { await $0.playAll(ids, volume: volume) }
    }

    public func warm(_ ids: [String], concurrentPlayerCount: Int) {
        guard !isDisabled else { return }
        enqueue { await $0.warm(ids, concurrentPlayerCount: concurrentPlayerCount) }
    }

    public func warmAllCatalog(concurrentPlayerCount: Int) {
        guard !isDisabled else { return }
        enqueue { $0.warmAllCatalog(concurrentPlayerCount: concurrentPlayerCount) }
    }

    public func stopAll() {
        enqueue { $0.stopAll() }
    }

    public func releaseResources() {
        enqueue { $0.releaseResources() }
    }

    private func enqueue(_ operation: @escaping @Sendable (isolated SFXPlayback) async -> Void) {
        continuation?.yield(operation)
    }
}

private actor SFXPlayback {
    private var engineIsRunning = false
    private var preparedVoicesArePlaying = false
    private lazy var engine = AVAudioEngine()
    private var preparedVoicesByID: [String: [PreparedSFXVoice]] = [:]
    private var buffersByID: [String: AVAudioPCMBuffer] = [:]
    private var failedBufferIDs: Set<String> = []
    private var nextVoiceIndexByID: [String: Int] = [:]
    private var catalogWarmTask: Task<Void, Never>?
    // Actor reentrancy lets a decode finish after stop or release; stale work
    // must not rebuild voices or restart the engine.
    private var resourceGeneration: UInt64 = 0
    private let logger = AudioSupport.logger()

    isolated deinit {
        catalogWarmTask?.cancel()
    }

    func playAll(_ ids: [String], volume: Double) async {
        guard volume > 0 else { return }
        guard !ids.isEmpty else { return }

        let generation = resourceGeneration
        guard await ensureReady(for: ids), generation == resourceGeneration else {
            return
        }
        for id in ids {
            guard let clip = SFXCatalog.clipsByID[id],
                  let voices = preparedVoicesByID[id],
                  !voices.isEmpty else { continue }
            let voiceIndex = (nextVoiceIndexByID[id] ?? 0) % voices.count
            nextVoiceIndexByID[id] = (voiceIndex + 1) % voices.count
            let voice = voices[voiceIndex]
            voice.node.volume = AudioSupport.targetVolume(appVolume: Float(max(0, volume)), gain: clip.volumeGain)
            voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts, completionHandler: nil)
        }
    }

    func warm(_ ids: [String], concurrentPlayerCount: Int) async {
        guard !Task.isCancelled else { return }
        let generation = resourceGeneration
        let desiredCount = max(1, concurrentPlayerCount)
        let idsNeedingWork = ids.filter { id in
            (preparedVoicesByID[id]?.count ?? 0) < desiredCount
        }
        guard !idsNeedingWork.isEmpty else {
            ensureStarted()
            return
        }

        configureSessionIfNeeded()

        for id in idsNeedingWork {
            guard let clip = SFXCatalog.clipsByID[id] else { continue }
            let buffer = await preparedBuffer(for: clip)
            guard generation == resourceGeneration, !Task.isCancelled else { return }
            guard let buffer else { continue }
            var voices = preparedVoicesByID[id, default: []]
            while voices.count < desiredCount {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
                voices.append(PreparedSFXVoice(node: node, buffer: buffer))
            }
            preparedVoicesByID[id] = voices
        }
        preparedVoicesArePlaying = false
        engine.prepare()
        ensureStarted()
    }

    func warmAllCatalog(concurrentPlayerCount: Int) {
        let ids = SFXCatalog.clips.map(\.id)
        catalogWarmTask?.cancel()
        catalogWarmTask = Task.detached(priority: .utility) { [weak self] in
            await self?.warm(ids, concurrentPlayerCount: concurrentPlayerCount)
        }
    }

    func stopAll() {
        resourceGeneration &+= 1
        catalogWarmTask?.cancel()
        catalogWarmTask = nil
        for voices in preparedVoicesByID.values {
            for voice in voices {
                voice.node.stop()
            }
        }
        preparedVoicesArePlaying = false
        engine.pause()
        engineIsRunning = false
    }

    func releaseResources() {
        stopAll()
        for voices in preparedVoicesByID.values {
            for voice in voices {
                engine.disconnectNodeOutput(voice.node)
                engine.detach(voice.node)
            }
        }
        preparedVoicesByID.removeAll(keepingCapacity: false)
        buffersByID.removeAll(keepingCapacity: false)
        failedBufferIDs.removeAll(keepingCapacity: false)
        nextVoiceIndexByID.removeAll(keepingCapacity: false)
        engine.stop()
        engine.reset()
    }

    private func ensureReady(for ids: [String]) async -> Bool {
        let generation = resourceGeneration
        let missing = ids.filter { preparedVoicesByID[$0] == nil && !failedBufferIDs.contains($0) }
        if !missing.isEmpty {
            await warm(missing, concurrentPlayerCount: 1)
        }
        guard generation == resourceGeneration, !Task.isCancelled else { return false }
        configureSessionIfNeeded()
        return ensureStarted()
    }

    /// Returns the cached buffer, decoding off-actor on a miss so file I/O
    /// never blocks already-warmed clips sharing this actor.
    private func preparedBuffer(for clip: SFXClip) async -> AVAudioPCMBuffer? {
        if let buffer = buffersByID[clip.id] {
            return buffer
        }
        if failedBufferIDs.contains(clip.id) {
            return nil
        }
        guard let url = Self.resourceURL(for: clip) else {
            failedBufferIDs.insert(clip.id)
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)",
            )
            return nil
        }
        let generation = resourceGeneration
        let decoded = await Task.detached(priority: .utility, operation: {
            SendableAudioBuffer(value: Self.decodePCMBuffer(at: url))
        }).value.value
        guard generation == resourceGeneration, !Task.isCancelled else { return nil }
        guard let buffer = decoded else {
            failedBufferIDs.insert(clip.id)
            return nil
        }
        buffersByID[clip.id] = buffer
        return buffer
    }

    private nonisolated static let decodeLogger = AudioSupport.logger()

    private nonisolated static func decodePCMBuffer(at url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0,
                  file.length <= AVAudioFramePosition(AVAudioFrameCount.max),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(file.length),
                  )
            else { return nil }
            try file.read(into: buffer)
            return buffer
        } catch {
            decodeLogger.error(
                "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            return nil
        }
    }

    private nonisolated static func resourceURL(for clip: SFXClip) -> URL? {
        AudioSupport.mediaURL(
            resourceName: clip.resourceName,
            fileExtension: clip.fileExtension,
            subdirectory: "SFX",
        )
    }

    /// Shared ensure-engine + start-voices epilogue. Returns whether the
    /// engine is running.
    @discardableResult
    private func ensureStarted() -> Bool {
        guard ensureEngineRunning() else { return false }
        startPreparedVoicesIfNeeded()
        return true
    }

    private func configureSessionIfNeeded() {
        AudioSession.configureIfNeeded(logger: logger)
    }

    private func ensureEngineRunning() -> Bool {
        if engineIsRunning, engine.isRunning {
            return true
        }
        guard !engine.isRunning else {
            engineIsRunning = true
            return true
        }
        preparedVoicesArePlaying = false
        do {
            try engine.start()
            engineIsRunning = true
            return true
        } catch {
            engineIsRunning = false
            logger.error(
                "Unable to start SFX engine: \(error.localizedDescription, privacy: .public)",
            )
            return false
        }
    }

    private func startPreparedVoicesIfNeeded() {
        guard !preparedVoicesArePlaying else { return }
        for voices in preparedVoicesByID.values {
            for voice in voices where !voice.node.isPlaying {
                voice.node.play()
            }
        }
        preparedVoicesArePlaying = true
    }
}

private struct PreparedSFXVoice {
    let node: AVAudioPlayerNode
    let buffer: AVAudioPCMBuffer
}

/// `AVAudioPCMBuffer` is not `Sendable`; decoding happens off-actor and the
/// result crosses back here. Transfers are serialized through the playback
/// actor's queue, so the unchecked box is confined after handoff.
/// Concurrency-Safety: confined to the playback actor after the await handoff.
private struct SendableAudioBuffer: @unchecked Sendable {
    let value: AVAudioPCMBuffer?
}
