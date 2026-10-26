import Testing
import TrinketCore
@testable import TrinketContent

struct WeightedLootSelectionTests {
    @Test func `weighted tickets preserve pool order and random stream`() {
        let weights = [0, 4, 0, 6, 7, 0]
        for seed in UInt64(0) ..< 256 {
            var expectedRandom = SeededRandomNumberGenerator(seed: seed)
            let ticket = Int.random(in: 1 ... 17, using: &expectedRandom)
            let expectedIndex = ticket <= 4 ? 1 : ticket <= 10 ? 3 : 4
            var random = SeededRandomNumberGenerator(seed: seed)
            let index = WeightedLootSelection.index(in: weights, totalWeight: 17, weight: { $0 }, using: &random)
            #expect(index == expectedIndex)
            #expect(random.next() == expectedRandom.next())
        }
    }

    @Test func `empty weight does not consume randomness`() {
        var random = SeededRandomNumberGenerator(seed: 42)
        var untouched = random
        #expect(WeightedLootSelection.index(in: [0, 0], totalWeight: 0, weight: { $0 }, using: &random) == nil)
        #expect(random.next() == untouched.next())
    }
}
