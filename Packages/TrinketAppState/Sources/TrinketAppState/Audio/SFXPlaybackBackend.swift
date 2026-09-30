import AVFoundation
import Foundation
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

struct SystemSFXPlaybackBackend: SFXPlaybackBackend {
    private lazy var engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private let logger = AudioSupport.logger()

    static func load(_ clip: SFXClip) async -> DecodedSFXBuffer? {
        let logger = AudioSupport.logger()
        guard let url = AudioSupport.mediaURL(
            resourceName: clip.resourceName, fileExtension: clip.fileExtension, subdirectory: "SFX",
        ) else {
            logger.warning("Missing SFX resource: \(clip.resourceName, privacy: .public).\(clip.fileExtension, privacy: .public)")
            return nil
        }
        return await Task.detached(priority: .utility) {
            do {
                let file = try AVAudioFile(forReading: url)
                guard file.length > 0,
                      file.length <= AVAudioFramePosition(AVAudioFrameCount.max),
                      let buffer = AVAudioPCMBuffer(
                          pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length),
                      ) else { return nil as DecodedSFXBuffer? }
                try file.read(into: buffer)
                return DecodedSFXBuffer(value: buffer)
            } catch {
                logger
                    .error(
                        "Unable to decode SFX resource \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)",
                    )
                return nil
            }
        }.value
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
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                logger.error("Unable to start SFX engine: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        for node in nodes where !node.isPlaying {
            node.play()
        }
        return true
    }

    func play(_ voice: PreparedSFXVoice, volume: Float) {
        voice.node.volume = volume
        voice.node.scheduleBuffer(voice.buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    mutating func stop() {
        for node in nodes {
            node.stop()
        }
        engine.pause()
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
