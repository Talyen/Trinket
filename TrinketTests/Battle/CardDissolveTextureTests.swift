import CoreGraphics
import Testing
@testable import Trinket

struct CardDissolveTextureTests {
    @Test func thresholdMaskImageDoesNotDeadlockOnCacheMiss() throws {
        // Regression: baking used to call noiseBytes while holding the threshold lock
        // (single non-recursive lock), freezing the UI on first card play.
        let image = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(image.width == 192)
        #expect(image.height == 256)
        // Second call should hit cache and still return a live image.
        let cached = try #require(CardDissolveTexture.thresholdMaskImage(progress: 0.45))
        #expect(cached.width == 192)
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
        #expect(low.width == 192)
        #expect(low.height == 256)
        #expect(high.width == 192)
        #expect(high.height == 256)
    }
}
