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
    mutating func releaseResources()
}

/// Nodes are append-only between releases. A running engine only needs to start
/// the newly appended suffix; a resumed engine must revisit every retained node.
struct SFXVoiceStartPolicy {
    private var startedCount = 0

    func indicesToStart(nodeCount: Int, engineWasRunning: Bool) -> Range<Int> {
        (engineWasRunning ? startedCount : 0) ..< nodeCount
    }

    mutating func didStart(nodeCount: Int) {
        startedCount = nodeCount
    }

    mutating func reset() {
        startedCount = 0
    }
}

struct SystemSFXPlaybackBackend: SFXPlaybackBackend {
    private lazy var engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var voiceStartPolicy = SFXVoiceStartPolicy()
    private let logger = AudioSupport.logger()

    @concurrent
    static func load(_ clip: SFXClip) async -> DecodedSFXBuffer? {
        let logger = AudioSupport.logger()
        guard let url = AudioSupport.mediaURL(
            resourceName: clip.resourceName, fileExtension: clip.fileExtension, subdirectory: "SFX",
        ) else {
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
            logger.error(
                "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)",
            )
            return nil
        }
    }

    mutating func makeVoice(buffer: DecodedSFXBuffer) -> PreparedSFXVoice {
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.value.format)
        nodes.append(node)
        return PreparedSFXVoice(node: node, buffer: buffer.value)
    }

    mutating func start() -> Bool {
        AudioSession.configureIfNeeded(logger: logger)
        let engineWasRunning = engine.isRunning
        if !engineWasRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                logger.error("Unable to start SFX engine: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        for index in voiceStartPolicy.indicesToStart(nodeCount: nodes.count, engineWasRunning: engineWasRunning) {
            let node = nodes[index]
            if !node.isPlaying {
                node.play()
            }
        }
        voiceStartPolicy.didStart(nodeCount: nodes.count)
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
    }

    mutating func stop() {
        for node in nodes {
            node.stop()
        }
        engine.pause()
        voiceStartPolicy.reset()
    }

    mutating func releaseResources() {
        stop()
        for node in nodes {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        nodes.removeAll()
        engine.stop()
        engine.reset()
    }
}

struct PreparedSFXVoice {
    let node: AVAudioPlayerNode
    let buffer: AVAudioPCMBuffer
}

/// Concurrency-Safety: the decoder exclusively owns the buffer until transfer;
/// afterward it is read only, and all engine access belongs to the audio actor.
struct DecodedSFXBuffer: @unchecked Sendable {
    let value: AVAudioPCMBuffer
}
