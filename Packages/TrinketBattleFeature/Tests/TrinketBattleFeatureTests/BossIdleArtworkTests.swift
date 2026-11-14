import AVFoundation
import Foundation
import Testing
@testable import TrinketBattleFeature

struct BossIdleArtworkTests {
    @Test func `shuffled rounds play every clip without adjacent repeats`() {
        for count in [3, 5] {
            var order = BossIdleOrder(count: count)
            let selections = (0 ..< count * 30).compactMap { _ in order.next() }
            #expect(selections.count == count * 30)
            for (previous, next) in zip(selections, selections.dropFirst()) {
                #expect(previous != next)
            }
            for start in stride(from: 0, to: selections.count, by: count) {
                #expect(Set(selections[start ..< start + count]) == Set(0 ..< count))
            }
        }
    }

    @Test func `opening clip matches the bundled first frame`() throws {
        for id in [
            "the_blight_treant",
            "the_forge_golem",
            "the_frostwarden",
            "the_iron_bear",
            "the_blood_countess",
            "the_seraph",
            "the_stone_titan",
        ] {
            let clips = try #require(BossIdleCatalog.clips(for: id))
            let first = try #require(clips.first)
            #expect(FileManager.default.fileExists(atPath: first.deletingPathExtension().path + "-first.png"))
            var order = BossIdleOrder(count: clips.count, initial: 0)
            #expect(order.next() == 0)
        }
    }

    @Test func `clip order prefers a compatible available successor`() {
        let scores: [[Double]] = [[0, 1, 100], [100, 0, 1], [1, 100, 0]]
        var order = BossIdleOrder(count: 3, scores: scores)
        let selections = (0 ..< 30).compactMap { _ in order.next() }
        #expect(selections.count == 30)
        for (previous, next) in zip(selections, selections.dropFirst()) {
            #expect(next == (previous + 1) % 3)
        }
    }

    @Test func `every boss has its complete bundled clip set`() {
        for (id, count) in [
            ("the_blight_treant", 3), ("the_forge_golem", 3), ("the_frostwarden", 3),
            ("the_iron_bear", 3), ("the_blood_countess", 5), ("the_seraph", 3), ("the_stone_titan", 3),
        ] {
            #expect(BossIdleCatalog.clips(for: id)?.count == count)
        }
        #expect(BossIdleCatalog.clips(for: "slime") == nil)
    }

    @Test func `clip data is loaded completely with a bounded per boss cache`() throws {
        let clips = try #require(BossIdleCatalog.clips(for: "the_blood_countess"))
        let data = try BossIdleClipCache.read(clips)
        #expect(data.count == clips.count)
        #expect(zip(data, clips).allSatisfy { bytes, url in
            bytes == (try? Data(contentsOf: url))
        })
        #expect(throws: BossIdleClipCache.Failure.self) {
            try BossIdleClipCache.read(clips, byteLimit: 1)
        }
    }

    @Test func `cached bytes support random access and an actual playable asset`() async throws {
        #expect(BossIdleCachedAsset.byteRange(offset: 4, requestedOffset: 4, length: 3, toEnd: false, count: 10) == 4 ..< 7)
        #expect(BossIdleCachedAsset.byteRange(offset: 6, requestedOffset: 4, length: 10, toEnd: false, count: 10) == 6 ..< 10)
        #expect(BossIdleCachedAsset.byteRange(offset: 6, requestedOffset: 4, length: 1, toEnd: true, count: 10) == 6 ..< 10)
        #expect(BossIdleCachedAsset.byteRange(offset: -1, requestedOffset: 0, length: 2, toEnd: false, count: 10) == nil)
        #expect(BossIdleCachedAsset.byteRange(offset: 11, requestedOffset: 11, length: 2, toEnd: false, count: 10) == nil)
        let url = try #require(BossIdleCatalog.clips(for: "the_blight_treant")?.first)
        let data = try Data(contentsOf: url)
        let cached = try #require(BossIdleCachedAsset(data: data, name: "test"))
        #expect(try await cached.asset.load(.isPlayable))
        #expect(try await cached.asset.load(.duration).seconds > 1)
    }

    @Test func `outgoing frame remains until the next frame is ready`() {
        var handoff = BossIdleHandoff()
        #expect(handoff.markReady(0) == .show(0))
        #expect(handoff.markSeam(0) == nil)
        #expect(handoff.active == 0)
        #expect(handoff.markReady(1) == .transition(from: 0, to: 1))
        #expect(handoff.markSeam(0) == nil)
        handoff.reset(0)
        #expect(handoff.markSeam(1) == nil)
        #expect(handoff.active == 1)
        #expect(handoff.markReady(0) == .transition(from: 1, to: 0))
    }

    @Test func `a prewarmed next clip waits until the active clip reaches the seam`() {
        var handoff = BossIdleHandoff()
        #expect(handoff.markReady(1) == nil)
        #expect(handoff.markReady(0) == .show(0))
        #expect(handoff.markSeam(0) == .transition(from: 0, to: 1))
        #expect(handoff.markReady(1) == nil)
    }

    @Test func `cancelled preload does not publish clips`() async {
        let urls = BossIdleCatalog.clips(for: "the_blight_treant") ?? []
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try BossIdleClipCache.read(urls)
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled cache read returned clips")
        } catch is CancellationError {
            // Expected: no partial cache is returned.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test @MainActor func `hidden prepared boss creates paused players`() async throws {
        let urls = try #require(BossIdleCatalog.clips(for: "the_forge_golem"))
        let view = BossIdlePlayerView()
        defer { view.stop() }
        view.prepare(clips: urls, isVisible: false, isForeground: true)
        for _ in 0 ..< 100 {
            let layers = view.layer.sublayers?.compactMap { $0 as? AVPlayerLayer } ?? []
            if layers.count == 2 {
                #expect(layers.allSatisfy { $0.player?.rate == 0 })
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Hidden boss players were not prepared")
    }

    @Test @MainActor func `retiring the player releases the view while preload is pending`() async throws {
        let urls = try #require(BossIdleCatalog.clips(for: "the_blood_countess"))
        var player: BossIdlePlayerView? = BossIdlePlayerView()
        weak var retiredPlayer = player
        player?.prepare(clips: urls, isVisible: true, isForeground: true)
        player?.stop()
        player = nil
        await Task.yield()
        #expect(retiredPlayer == nil)
    }
}
