import Testing
import TrinketCore

struct SeededRandomNumberGeneratorTests {
    @Test func `same seed replays the same sequence`() {
        var first = SeededRandomNumberGenerator(seed: 1772)
        var second = SeededRandomNumberGenerator(seed: 1772)
        #expect((0 ..< 8).map { _ in first.next() } == (0 ..< 8).map { _ in second.next() })
    }

    @Test func `different seeds diverge`() {
        var first = SeededRandomNumberGenerator(seed: 1772)
        var second = SeededRandomNumberGenerator(seed: 1773)
        #expect((0 ..< 8).map { _ in first.next() } != (0 ..< 8).map { _ in second.next() })
    }

    @Test func `zero seed still advances`() {
        var generator = SeededRandomNumberGenerator(seed: 0)
        let draws = (0 ..< 4).map { _ in generator.next() }
        #expect(Set(draws).count > 1)
    }
}
