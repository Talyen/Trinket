import AVFoundation
import Foundation
import os
import TrinketContent

@MainActor
public final class SFXPlayer {
    private let isDisabled: Bool
    private var hasConfiguredSession = false
    private var engineIsRunning = false
    private var preparedVoicesArePlaying = false
    private let engine = AVAudioEngine()
    private var preparedVoicesByID: [String: [PreparedSFXVoice]] = [:]
    private var buffersByID: [String: AVAudioPCMBuffer] = [:]
    private var nextVoiceIndexByID: [String: Int] = [:]
    private var catalogWarmTask: Task<Void, Never>?
    private let logger = Logger(
        subsystem: AudioLogging.subsystem,
        category: "Audio",
    )

    public init(isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    public func play(_ id: String, volume: Double) {
        playAll([id], volume: volume)
    }

    public func playAll(_ ids: [String], volume: Double) {
        guard !isDisabled else { return }
        guard volume > 0 else { return }
        guard !ids.isEmpty else { return }

        if !ensureReady(for: ids) {
            return
        }
        let gain = max(0, volume)
        for id in ids {
            guard let clip = SFXCatalog.clipsByID[id],
                  let voices = preparedVoicesByID[id],
                  !voices.isEmpty else { continue }
            let voiceIndex = (nextVoiceIndexByID[id] ?? 0) % voices.count
            nextVoiceIndexByID[id] = (voiceIndex + 1) % voices.count
            let voice = voices[voiceIndex]
            voice.node.volume = min(Float(gain * max(0, clip.volumeGain)), 1)
            voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts)
        }
    }

    public func warm(_ ids: [String], concurrentPlayerCount: Int = 1) {
        guard !isDisabled else { return }
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
            guard let buffer = preparedBuffer(for: clip) else { continue }
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

    public func warmAllCatalog(concurrentPlayerCount: Int = 2) {
        guard !isDisabled else { return }
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
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                for (id, buffer) in decoded {
                    buffersByID[id] = buffer
                }
                warm(ids, concurrentPlayerCount: concurrentPlayerCount)
            }
        }
    }

    public func stopAll() {
        for voices in preparedVoicesByID.values {
            for voice in voices {
                voice.node.stop()
            }
        }
        preparedVoicesArePlaying = false
        engine.pause()
        engineIsRunning = false
    }

    public func releaseResources() {
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
        nextVoiceIndexByID.removeAll(keepingCapacity: false)
        engine.stop()
        engine.reset()
    }

    private func ensureReady(for ids: [String]) -> Bool {
        let missing = ids.filter { preparedVoicesByID[$0] == nil }
        if !missing.isEmpty {
            warm(missing)
            return engineIsRunning
        }
        configureSessionIfNeeded()
        guard ensureEngineRunning() else { return false }
        startPreparedVoicesIfNeeded()
        return true
    }

    private func preparedBuffer(for clip: SFXClip) -> AVAudioPCMBuffer? {
        if let buffer = buffersByID[clip.id] {
            return buffer
        }
        guard let url = Self.resourceURL(for: clip) else {
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)",
            )
            return nil
        }
        guard let buffer = Self.decodePCMBuffer(at: url) else { return nil }
        buffersByID[clip.id] = buffer
        return buffer
    }

    // swiftformat:disable:next modifierOrder
    nonisolated private static let decodeLogger = Logger(
        subsystem: AudioLogging.subsystem,
        category: "Audio",
    )

    // swiftformat:disable:next modifierOrder
    nonisolated private static func decodePCMBuffer(at url: URL) -> AVAudioPCMBuffer? {
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

    // swiftformat:disable:next modifierOrder
    nonisolated private static func resourceURL(for clip: SFXClip) -> URL? {
        Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension) ??
            Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension, subdirectory: "SFX") ??
            Bundle.main.url(
                forResource: clip.resourceName,
                withExtension: clip.fileExtension,
                subdirectory: "Media/SFX",
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
            for voice in voices {
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
