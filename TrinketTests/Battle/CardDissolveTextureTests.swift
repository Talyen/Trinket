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

    @Test func prewarmCompletesWithoutNestedLock() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task.detached(priority: .userInitiated) {
                CardDissolveTexture.prewarm()
                // prewarm itself is async; exercise a sync bake after kicking it off.
                _ = CardDissolveTexture.thresholdMaskImage(progress: 0.2)
                _ = CardDissolveTexture.thresholdMaskImage(progress: 0.8)
                continuation.resume()
            }
        }
    }
}
