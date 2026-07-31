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
    private let logger = Logger(
        subsystem: AudioLogging.subsystem,
        category: "Audio"
    )

    public init(isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    public func play(_ id: String, volume: Double) {
        playAll([id], volume: volume)
    }

    /// Plays several one-shots on the same frame with a single engine/session check.
    /// Dense multimodal stacks this with hit reactions; the hot path must stay
    /// schedule-only (no stop / attach / decode).
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
            // `.interrupts` replaces any in-flight buffer without a synchronous stop().
            voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts)
        }
    }

    /// Prepares a small overlap pool. Battle uses two players per clip so rapid
    /// target staggers do not allocate or cut off the immediately preceding hit.
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

    public func stopAll() {
        for voices in preparedVoicesByID.values {
            for voice in voices {
                voice.node.stop()
            }
        }
        preparedVoicesArePlaying = false
    }

    private func ensureReady(for ids: [String]) -> Bool {
        let missing = ids.filter { preparedVoicesByID[$0] == nil }
        if !missing.isEmpty {
            warm(missing)
        } else {
            configureSessionIfNeeded()
            _ = ensureEngineRunning()
        }
        guard ensureEngineRunning() else { return false }
        startPreparedVoicesIfNeeded()
        return true
    }

    private func preparedBuffer(for clip: SFXClip) -> AVAudioPCMBuffer? {
        if let buffer = buffersByID[clip.id] {
            return buffer
        }
        guard let url = resourceURL(for: clip) else {
            logger.warning(
                "Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)"
            )
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0,
                  file.length <= AVAudioFramePosition(AVAudioFrameCount.max),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat,
                      frameCapacity: AVAudioFrameCount(file.length)
                  ) else { return nil }
            try file.read(into: buffer)
            buffersByID[clip.id] = buffer
            return buffer
        } catch {
            logger.error(
                "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func resourceURL(for clip: SFXClip) -> URL? {
        Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension) ??
            Bundle.main.url(forResource: clip.resourceName, withExtension: clip.fileExtension, subdirectory: "SFX") ??
            Bundle.main.url(
                forResource: clip.resourceName,
                withExtension: clip.fileExtension,
                subdirectory: "Resources/SFX"
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
                "Unable to start SFX engine: \(error.localizedDescription, privacy: .public)"
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
