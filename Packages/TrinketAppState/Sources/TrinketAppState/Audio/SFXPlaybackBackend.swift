import AVFoundation
import Foundation
import os
import TrinketContent

/// The coordinator exclusively owns this backend. Decoding returns transferable
/// buffers; engine and voice access stays on the coordinator's audio actor.
protocol SFXPlaybackBackend {
    associatedtype Buffer: Sendable
    associatedtype Voice

    static func load(_ clip: SFXClip) async -> Buffer?
    mutating func makeVoice(buffer: Buffer) -> Voice
    mutating func start() -> Bool
    mutating func play(_ voice: Voice, volume: Float)
    mutating func stop()
    /// Stops playback and discards all voices and engine resources.
    mutating func releaseResources()
}

/// Nodes are append-only between releases. A running engine only needs to start
/// the newly appended suffix; a resumed engine must revisit every retained node.
struct SystemSFXPlaybackBackend: SFXPlaybackBackend {
    private var engine: AVAudioEngine?
    private var nodes: [AVAudioPlayerNode] = []
    private var startedVoiceCount = 0
    private let logger = AudioSupport.logger()

    @concurrent
    static func load(_ clip: SFXClip) async -> DecodedSFXBuffer? {
        let logger = AudioSupport.logger()
        guard let url = AudioSupport.mediaURL(
            resourceName: clip.resourceName, fileExtension: clip.fileExtension, subdirectory: "SFX",
        ) else {
            #if DEBUG
            AudioCoverageDiagnostics.failed()
            #endif
            logger.warning("Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)")
            return nil
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0,
                  file.length <= AVAudioFramePosition(AVAudioFrameCount.max),
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length),
                  ) else { return nil }
            try file.read(into: buffer)
            return DecodedSFXBuffer(value: buffer)
        } catch {
            #if DEBUG
            AudioCoverageDiagnostics.failed()
            #endif
            logger.error(
                "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            return nil
        }
    }

    mutating func makeVoice(buffer: DecodedSFXBuffer) -> PreparedSFXVoice {
        let engine = prepareEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.value.format)
        nodes.append(node)
        return PreparedSFXVoice(node: node, buffer: buffer.value)
    }

    mutating func start() -> Bool {
        AudioSession.configureIfNeeded(logger: logger)
        let engine = prepareEngine()
        let engineWasRunning = engine.isRunning
        if !engineWasRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                #if DEBUG
                AudioCoverageDiagnostics.failed()
                #endif
                logger.error("Unable to start SFX engine: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        for index in (engineWasRunning ? startedVoiceCount : 0) ..< nodes.count {
            let node = nodes[index]
            if !node.isPlaying {
                node.play()
            }
        }
        #if DEBUG
        if !engineWasRunning {
            AudioCoverageDiagnostics.sfxStarted()
        }
        #endif
        startedVoiceCount = nodes.count
        return true
    }

    func play(_ voice: PreparedSFXVoice, volume: Float) {
        // Recover a selected node stopped by the audio system without scanning
        // unrelated voices on every sound request.
        if !voice.node.isPlaying {
            voice.node.play()
        }
        voice.node.volume = volume
        voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts, completionHandler: nil)
        #if DEBUG
        AudioCoverageDiagnostics.sfxPlayed()
        #endif
    }

    mutating func stop() {
        for node in nodes {
            node.stop()
        }
        engine?.pause()
        startedVoiceCount = 0
    }

    mutating func releaseResources() {
        stop()
        guard let engine else { return }
        for node in nodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        nodes.removeAll()
        engine.stop()
        engine.reset()
        self.engine = nil
    }

    private mutating func prepareEngine() -> AVAudioEngine {
        if let engine {
            return engine
        }
        let engine = AVAudioEngine()
        self.engine = engine
        return engine
    }
}

struct PreparedSFXVoice {
    fileprivate let node: AVAudioPlayerNode
    fileprivate let buffer: AVAudioPCMBuffer
}

/// Concurrency-Safety: the decoder exclusively owns the buffer until transfer;
/// afterward it is read only, and all engine access belongs to the audio actor.
struct DecodedSFXBuffer: @unchecked Sendable {
    fileprivate let value: AVAudioPCMBuffer
}
