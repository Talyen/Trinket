import Foundation
import Testing
import TrinketContent
@testable import TrinketAppState

@MainActor
struct MusicPlayerTests {
    @Test func `disabled player never loads or activates audio`() throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: true, backend: backend)
        let request = try request("disabled")
        player.prepare(request)
        player.update(route: .track(request), volume: 1)
        player.setVolume(0.5)
        player.silenceImmediately(preservingPosition: true)
        #expect(!player.canPreviewVolume)
        #expect(backend.loads.isEmpty)
        #expect(backend.activations == 0)
    }

    @Test func `superseded and silenced loads cannot start music`() async throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: false, backend: backend)
        try player.update(route: .track(request("first")), volume: 1)
        try await eventually { backend.loads.count == 1 }
        try player.update(route: .track(request("second")), volume: 1)
        try await eventually { backend.loads.count == 2 }
        let stale = TestMusicVoice()
        backend.completeLoad(0, with: stale)
        try await eventually { stale.stops == 1 }
        #expect(stale.starts == 0)
        player.silenceImmediately(preservingPosition: true)
        let silenced = TestMusicVoice()
        backend.completeLoad(1, with: silenced)
        try await eventually { silenced.stops == 1 }
        #expect(silenced.starts == 0)
        #expect(!player.canPreviewVolume)
    }

    @Test func `prepared replacement stops old voice and resumes its latest position`() async throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: false, backend: backend)
        let first = try request("first")
        let second = try request("second")
        let outgoing = try await start(first, player: player, backend: backend)
        outgoing.currentTime = 12
        player.prepare(second)
        try await eventually { backend.loads.count == 2 }
        let prepared = TestMusicVoice()
        backend.completeLoad(1, with: prepared)
        try await eventually { prepared.configurations > 0 }
        #expect(prepared.starts == 0)
        outgoing.currentTime = 27
        player.update(route: .track(second), volume: 0.5)
        #expect(outgoing.stops == 1)
        #expect(prepared.starts == 1)
        #expect(backend.steps.isEmpty)
        player.silenceImmediately(preservingPosition: true)
        let resumed = try await start(first, player: player, backend: backend)
        #expect(resumed.currentTime == 27)
    }

    @Test func `slider wins over cancellation during final fade suspension`() async throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: false, backend: backend)
        let outgoing = try await start(request("first"), player: player, backend: backend)
        let second = try request("second")
        let incoming = try await start(second, player: player, backend: backend)
        for index in 0 ..< 17 {
            try await eventually { backend.steps.count > index }
            backend.completeStep(index)
        }
        try await eventually { backend.steps.count == 18 }
        player.setVolume(0.2)
        #expect(outgoing.stops == 1)
        let expected = AudioSupport.targetVolume(appVolume: 0.2, gain: second.track.volumeGain)
        #expect(incoming.volume == expected)
        backend.completeStep(17)
        try await eventually { backend.resumedSteps == 18 }
        #expect(incoming.volume == expected)
        #expect(incoming.isPlaying)
        #expect(outgoing.stops == 1)
    }

    @Test func `immediate silence owns both voices of an interrupted crossfade`() async throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: false, backend: backend)
        let outgoing = try await start(request("first"), player: player, backend: backend)
        let incoming = try await start(request("second"), player: player, backend: backend)
        try await eventually { backend.steps.count == 1 }
        player.silenceImmediately(preservingPosition: true)
        #expect(outgoing.stops == 1)
        #expect(incoming.stops == 1)
        #expect(!player.canPreviewVolume)
        backend.completeStep(0)
        try await eventually { backend.resumedSteps == 1 }
        #expect(!outgoing.isPlaying && !incoming.isPlaying)
    }

    @Test func `muted decode is reused by slider and clearing encounter positions prevents resurrection`() async throws {
        let backend = ControlledMusicBackend()
        let player = MusicPlayer(isDisabled: false, backend: backend)
        let request = try request("encounter")
        player.prepare(request)
        try await eventually { backend.loads.count == 1 }
        let prepared = TestMusicVoice()
        backend.completeLoad(0, with: prepared)
        try await eventually { prepared.configurations > 0 }
        player.prepare(request)
        player.setVolume(0.5)
        #expect(prepared.starts == 1)
        #expect(backend.loads.count == 1)
        prepared.currentTime = 33
        player.clearEncounterResumePositions()
        player.silenceImmediately(preservingPosition: true)
        let restarted = try await start(request, player: player, backend: backend)
        #expect(restarted.currentTime == 0)
    }

    private func request(_ enemyID: String) throws -> MusicPlaybackRequest {
        let id = try #require(MusicCatalog.battleTrackIDs.first)
        let track = try #require(MusicCatalog.track(matching: id))
        return .resumable(track: track, contextKind: .battle, enemyID: enemyID)
    }

    private func start(
        _ request: MusicPlaybackRequest, player: MusicPlayer, backend: ControlledMusicBackend,
    ) async throws -> TestMusicVoice {
        let index = backend.loads.count
        player.update(route: .track(request), volume: 1)
        try await eventually { backend.loads.count > index }
        let voice = TestMusicVoice()
        backend.completeLoad(index, with: voice)
        try await eventually { voice.starts == 1 }
        return voice
    }

    private func eventually(_ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !condition(), clock.now < deadline {
            await Task.yield()
        }
        try #require(condition())
    }
}

@MainActor
private final class TestMusicVoice: MusicPlaybackVoice {
    var volume: Float = 0
    var currentTime: TimeInterval = 0
    let duration: TimeInterval = 120
    var isPlaying = false
    var numberOfLoops = 0 {
        didSet { configurations += 1 }
    }

    var configurations = 0
    var starts = 0
    var stops = 0

    func start() {
        starts += 1
        isPlaying = true
    }

    func stop() {
        stops += 1
        isPlaying = false
    }
}

@MainActor
private final class ControlledMusicBackend: MusicPlaybackBackend {
    var loads: [CheckedContinuation<(any MusicPlaybackVoice)?, Never>?] = []
    var steps: [CheckedContinuation<Void, Never>?] = []
    var activations = 0
    var resumedSteps = 0

    func load(_: MusicTrack) async -> (any MusicPlaybackVoice)? {
        await withCheckedContinuation { loads.append($0) }
    }

    func activateSession() {
        activations += 1
    }

    /// Deliberately completes cancelled waits to exercise stale asynchronous work.
    func waitForFadeStep(_: Duration) async {
        await withCheckedContinuation { steps.append($0) }
        resumedSteps += 1
    }

    func completeLoad(_ index: Int, with voice: TestMusicVoice?) {
        let continuation = loads[index]
        loads[index] = nil
        continuation?.resume(returning: voice)
    }

    func completeStep(_ index: Int) {
        let continuation = steps[index]
        steps[index] = nil
        continuation?.resume()
    }
}
