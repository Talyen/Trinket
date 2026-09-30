import Foundation
import Synchronization
import Testing
import TrinketContent
@testable import TrinketAppState

struct SFXPlaybackTests {
    @Test func `voice pools share decoding and rotate without rebuilding after stop`() async {
        let events = SFXEvents()
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            events.append("load:\(clip.id)")
            return clip.id
        }
        let id = SFXCatalog.clips[0].id
        await playback.execute(.warm([id, id], voiceCount: 2))
        await playback.execute(.play([id, id, id], volume: 0.8))
        await playback.execute(.stop)
        await playback.execute(.play([id], volume: 0.8))
        #expect(events.values.count(where: { $0 == "load:\(id)" }) == 1)
        #expect(events.values.count(where: { $0.hasPrefix("voice:") }) == 2)
        #expect(events.values.filter { $0.hasPrefix("play:") } == ["play:0", "play:1", "play:0", "play:1"])
    }

    @Test(arguments: [SFXCommand.stop, .release])
    func `invalidation prevents a suspended decode from restarting audio`(_ command: SFXCommand) async {
        let events = SFXEvents()
        let gate = SFXLoadGate()
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            await gate.load(clip.id)
        }
        let id = SFXCatalog.clips[0].id
        let warm = Task { await playback.execute(.warm([id], voiceCount: 2)) }
        await gate.waitForLoad()
        await playback.execute(command)
        await gate.finish()
        await warm.value
        #expect(!events.values.contains { $0.hasPrefix("voice:") || $0 == "start" || $0.hasPrefix("play:") })
    }

    @Test func `release clears failed loads so a restored resource can play`() async {
        let events = SFXEvents()
        let available = Mutex(false)
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            events.append("load")
            return available.withLock { $0 } ? clip.id : nil
        }
        let id = SFXCatalog.clips[0].id
        await playback.execute(.play([id], volume: 0.8))
        available.withLock { $0 = true }
        await playback.execute(.play([id], volume: 0.8))
        #expect(!events.values.contains("play:0"))
        await playback.execute(.release)
        await playback.execute(.play([id], volume: 0.8))
        #expect(events.values.count(where: { $0 == "load" }) == 2)
        #expect(events.values.contains("play:0"))
    }

    @Test func `overlapping warmups share one decode and grow the latest pool`() async {
        let events = SFXEvents()
        let gate = SFXLoadGate()
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            events.append("load")
            return await gate.load(clip.id)
        }
        let id = SFXCatalog.clips[0].id
        let first = Task { await playback.execute(.warm([id], voiceCount: 1)) }
        await gate.waitForLoad()
        let second = Task { await playback.execute(.warm([id], voiceCount: 3)) }
        await gate.finish()
        await first.value
        await second.value
        #expect(events.values.count(where: { $0 == "load" }) == 1)
        #expect(events.values.count(where: { $0.hasPrefix("voice:") }) == 3)
    }
}

private final class SFXEvents: Sendable {
    private let storage = Mutex<[String]>([])

    var values: [String] {
        storage.withLock { $0 }
    }

    func append(_ event: String) {
        storage.withLock { $0.append(event) }
    }
}

private struct TestSFXBackend: SFXPlaybackBackend {
    let events: SFXEvents
    private var nextVoice = 0

    init(events: SFXEvents) {
        self.events = events
    }

    static func load(_: SFXClip) -> String? {
        nil
    }

    mutating func makeVoice(buffer _: String) -> Int {
        defer { nextVoice += 1 }
        events.append("voice:\(nextVoice)")
        return nextVoice
    }

    func start() -> Bool {
        events.append("start")
        return true
    }

    func play(_ voice: Int, volume _: Float) {
        events.append("play:\(voice)")
    }

    func stop() {
        events.append("stop")
    }

    mutating func releaseResources() {
        events.append("release")
        nextVoice = 0
    }
}

private actor SFXLoadGate {
    private var result: CheckedContinuation<String?, Never>?
    private var arrival: CheckedContinuation<Void, Never>?

    func load(_ id: String) async -> String? {
        await withCheckedContinuation { continuation in
            result = continuation
            arrival?.resume()
            arrival = nil
        }.map { _ in id }
    }

    func waitForLoad() async {
        if result != nil {
            return
        }
        await withCheckedContinuation { arrival = $0 }
    }

    func finish() {
        result?.resume(returning: "loaded")
        result = nil
    }
}
