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
        #expect(events.values.filter { $0.hasPrefix("startVoice:") } == ["startVoice:0", "startVoice:1", "startVoice:0", "startVoice:1"])
    }

    @Test func `running pools only start newly warmed voices`() async {
        let events = SFXEvents()
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { $0.id }
        let id = SFXCatalog.clips[0].id
        await playback.execute(.warm([id], voiceCount: 1))
        await playback.execute(.play([id], volume: 0.8))
        await playback.execute(.warm([id], voiceCount: 3))
        await playback.execute(.play([id, id, id], volume: 0.8))
        #expect(events.values.filter { $0.hasPrefix("startVoice:") } == ["startVoice:0", "startVoice:1", "startVoice:2"])
        #expect(events.values.filter { $0.hasPrefix("play:") } == ["play:0", "play:0", "play:1", "play:2"])
    }

    @Test func `failed engine start retries retained voices without decoding again`() async {
        let events = SFXEvents()
        events.canStart = false
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            events.append("load")
            return clip.id
        }
        let id = SFXCatalog.clips[0].id
        await playback.execute(.warm([id], voiceCount: 2))
        #expect(!events.values.contains { $0.hasPrefix("startVoice:") })
        events.canStart = true
        await playback.execute(.play([id], volume: 0.8))
        #expect(events.values.count(where: { $0 == "load" }) == 1)
        #expect(events.values.filter { $0.hasPrefix("startVoice:") } == ["startVoice:0", "startVoice:1"])
        #expect(events.values.contains("play:0"))
    }

    @Test func `release reloads and prestarts a fresh voice pool`() async {
        let events = SFXEvents()
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            events.append("load")
            return clip.id
        }
        let id = SFXCatalog.clips[0].id
        await playback.execute(.warm([id], voiceCount: 3))
        await playback.execute(.release)
        await playback.execute(.play([id], volume: 0.8))
        #expect(events.values.count(where: { $0 == "load" }) == 2)
        #expect(events.values.filter { $0.hasPrefix("startVoice:") } == ["startVoice:0", "startVoice:1", "startVoice:2", "startVoice:0"])
    }

    @Test func `external engine suspension restarts all retained voices`() {
        var policy = SFXVoiceStartPolicy()
        policy.didStart(nodeCount: 3)
        #expect(policy.indicesToStart(nodeCount: 3, engineWasRunning: true).isEmpty)
        #expect(policy.indicesToStart(nodeCount: 3, engineWasRunning: false) == 0 ..< 3)
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

    @MainActor
    @Test(arguments: [false, true], [SFXCommand.stop, .release])
    func `player invalidates suspended foreground work and queued sounds`(
        isPlay: Bool,
        invalidation: SFXCommand,
    ) async {
        let events = SFXEvents()
        let gate = SFXLoadGate()
        let completion = SFXCommandCompletion()
        let suspendedID = SFXCatalog.clips[0].id
        let futureID = SFXCatalog.clips[1].id
        let playback = SFXPlayback(backend: TestSFXBackend(events: events)) { clip in
            if clip.id == suspendedID {
                return await gate.load(clip.id)
            }
            return clip.id
        }
        let player = SFXPlayer { command in
            await playback.execute(command)
            switch command {
            case let .play(ids, _):
                await completion.finish(ids == [futureID] ? "future" : "foreground")
            case .warm: await completion.finish("foreground")
            case .stop, .release: await completion.finish("invalidation")
            case .warmCatalog: break
            }
        }
        if isPlay {
            player.play(suspendedID, volume: 0.8)
        } else {
            player.warm([suspendedID], concurrentPlayerCount: 2)
        }
        await gate.waitForLoad()
        player.play(suspendedID, volume: 0.8)
        switch invalidation {
        case .stop: player.stopAll()
        default: player.releaseResources()
        }
        // Invalidation must complete before the decoder is allowed to return.
        await completion.wait(for: "invalidation")
        #expect(events.values.contains("stop"))
        if case .release = invalidation {
            #expect(events.values.contains("release"))
        }
        await gate.finish()
        await completion.wait(for: "foreground")
        #expect(!events.values.contains { $0.hasPrefix("voice:") || $0 == "start" || $0.hasPrefix("play:") })
        player.play(futureID, volume: 0.8)
        await completion.wait(for: "future")
        #expect(events.values.filter { $0.hasPrefix("play:") } == ["play:0"])
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

private actor SFXCommandCompletion {
    private var completed: Set<String> = []
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]

    func finish(_ name: String) {
        completed.insert(name)
        waiters.removeValue(forKey: name)?.resume()
    }

    func wait(for name: String) async {
        guard !completed.contains(name) else { return }
        await withCheckedContinuation { waiters[name] = $0 }
    }
}

private final class SFXEvents: Sendable {
    private let storage = Mutex<[String]>([])
    private let startAllowed = Mutex(true)

    var canStart: Bool {
        get { startAllowed.withLock { $0 } }
        set { startAllowed.withLock { $0 = newValue } }
    }

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
    private var isRunning = false
    private var voiceStartPolicy = SFXVoiceStartPolicy()

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

    mutating func start() -> Bool {
        events.append("start")
        guard events.canStart else { return false }
        for index in voiceStartPolicy.indicesToStart(nodeCount: nextVoice, engineWasRunning: isRunning) {
            events.append("startVoice:\(index)")
        }
        voiceStartPolicy.didStart(nodeCount: nextVoice)
        isRunning = true
        return true
    }

    func play(_ voice: Int, volume _: Float) {
        events.append("play:\(voice)")
    }

    mutating func stop() {
        events.append("stop")
        isRunning = false
        voiceStartPolicy.reset()
    }

    mutating func releaseResources() {
        stop()
        events.append("release")
        nextVoice = 0
    }
}

private actor SFXLoadGate {
    private var loadContinuations: [CheckedContinuation<Void, Never>] = []
    private var arrival: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func load(_ id: String) async -> String? {
        guard !isOpen else { return id }
        await withCheckedContinuation { continuation in
            loadContinuations.append(continuation)
            arrival?.resume()
            arrival = nil
        }
        return id
    }

    func waitForLoad() async {
        guard loadContinuations.isEmpty else { return }
        await withCheckedContinuation { arrival = $0 }
    }

    func finish() {
        // A duplicate decode should fail the load-count assertion without stranding either caller.
        isOpen = true
        let pending = loadContinuations
        loadContinuations.removeAll()
        for continuation in pending {
            continuation.resume()
        }
    }
}
