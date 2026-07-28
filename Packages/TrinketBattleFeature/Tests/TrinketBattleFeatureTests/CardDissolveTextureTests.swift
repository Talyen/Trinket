import CoreGraphics
import Testing
import TrinketFeatureSupport
@testable import TrinketBattleFeature

struct CardDissolveTextureTests {
    @Test func thresholdMaskImageDoesNotDeadlockOnCacheMiss() throws {
        // Cold miss must return immediately (provisional) without baking on-thread.
        let image = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(image.width > 0)
        #expect(image.height > 0)
        let cached = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(cached.width == image.width)
        #expect(cached.height == image.height)
    }

    @Test func prepareFillsRealThresholdCache() async throws {
        await CardDissolveTexture.prepare()
        let image = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(image.width > 0)
        #expect(image.height > 0)
        // Second call should hit the real cache.
        let cached = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(cached === image)
    }

    @Test func prewarmCompletesWithoutNestedLock() async throws {
        // Regression: concurrent prewarm + sync bake must not deadlock on the
        // shared Mutex. Completing with live masks is the semantic assert.
        let images = await withCheckedContinuation { (continuation: CheckedContinuation<(CGImage?, CGImage?), Never>) in
            Task.detached(priority: .userInitiated) {
                CardDissolveTexture.prewarm()
                let low = CardDissolveTexture.thresholdMaskImage(progress: 0.2)
                let high = CardDissolveTexture.thresholdMaskImage(progress: 0.8)
                continuation.resume(returning: (low, high))
            }
        }
        let low = try #require(images.0)
        let high = try #require(images.1)
        #expect(low.width > 0)
        #expect(low.height > 0)
        #expect(high.width > 0)
        #expect(high.height > 0)
    }
}
