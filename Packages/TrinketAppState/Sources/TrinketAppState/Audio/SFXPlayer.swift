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

    public func warm(_ ids: [String], concurrentPlayerCount: Int = 1) {
        guard !isDisabled else { return }
        enqueue { await $0.warm(ids, concurrentPlayerCount: concurrentPlayerCount) }
    }

    public func warmAllCatalog(concurrentPlayerCount: Int = 2) {
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
    private var hasConfiguredSession = false
    private var engineIsRunning = false
    private var preparedVoicesArePlaying = false
    private lazy var engine = AVAudioEngine()
    private var preparedVoicesByID: [String: [PreparedSFXVoice]] = [:]
    private var buffersByID: [String: AVAudioPCMBuffer] = [:]
    private var failedBufferIDs: Set<String> = []
    private var nextVoiceIndexByID: [String: Int] = [:]
    private var catalogWarmTask: Task<Void, Never>?
    private let logger = AudioSupport.logger()

    isolated deinit {
        catalogWarmTask?.cancel()
    }

    func playAll(_ ids: [String], volume: Double) async {
        guard volume > 0 else { return }
        guard !ids.isEmpty else { return }

        guard await ensureReady(for: ids) else {
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

    func warm(_ ids: [String], concurrentPlayerCount: Int = 1) async {
        let desiredCount = max(1, concurrentPlayerCount)
        let idsNeedingWork = ids.filter { id in
            (preparedVoicesByID[id]?.count ?? 0) < desiredCount
        }
        guard !idsNeedingWork.isEmpty else {
            if ensureEngineRunning() {
                startPreparedVoicesIfNeeded()
            }
            return
        }

        configureSessionIfNeeded()

        for id in idsNeedingWork {
            guard let clip = SFXCatalog.clipsByID[id] else { continue }
            guard let buffer = await preparedBuffer(for: clip) else { continue }
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
        if ensureEngineRunning() {
            startPreparedVoicesIfNeeded()
        }
    }

    func warmAllCatalog(concurrentPlayerCount: Int = 2) {
        let ids = SFXCatalog.clips.map(\.id)
        let clips = SFXCatalog.clips
        catalogWarmTask?.cancel()
        catalogWarmTask = Task.detached(priority: .utility) { [weak self] in
            var decoded: [String: AVAudioPCMBuffer] = [:]
            for clip in clips {
                if Task.isCancelled {
                    return
                }
                guard let url = Self.resourceURL(for: clip),
                      let buffer = Self.decodePCMBuffer(at: url)
                else { continue }
                decoded[clip.id] = buffer
            }
            await self?.finishCatalogWarmup(decoded, ids: ids, concurrentPlayerCount: concurrentPlayerCount)
        }
    }

    private func finishCatalogWarmup(
        _ decoded: [String: AVAudioPCMBuffer],
        ids: [String],
        concurrentPlayerCount: Int,
    ) async {
        // Task identity is preserved across the actor hop: this still refers to
        // the detached decode task, so a cancel-after-decode still discards the
        // stale batch here before it can install voices.
        guard !Task.isCancelled else { return }
        buffersByID.merge(decoded) { existing, _ in existing }
        await warm(ids, concurrentPlayerCount: concurrentPlayerCount)
    }

    func stopAll() {
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
        catalogWarmTask?.cancel()
        catalogWarmTask = nil
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
        let missing = ids.filter { preparedVoicesByID[$0] == nil && !failedBufferIDs.contains($0) }
        if !missing.isEmpty {
            await warm(missing)
        }
        configureSessionIfNeeded()
        guard ensureEngineRunning() else { return false }
        startPreparedVoicesIfNeeded()
        return true
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
        guard let buffer = await Task.detached(priority: .utility, operation: {
            SendableAudioBuffer(value: Self.decodePCMBuffer(at: url))
        }).value.value else {
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
        AudioResourceLocator.url(
            resourceName: clip.resourceName,
            fileExtension: clip.fileExtension,
            subdirectory: "SFX",
        )
    }

    private func configureSessionIfNeeded() {
        AmbientAudioSession.configureIfNeeded(configured: &hasConfiguredSession, logger: logger)
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
