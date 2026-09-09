import Testing
import TrinketCore

struct SeededRandomNumberGeneratorTests {
    @Test func `same seed replays the same sequence`() {
        var first = SeededRandomNumberGenerator(seed: 1772)
        var second = SeededRandomNumberGenerator(seed: 1772)
        #expect(first.next() == second.next())
        #expect(first.next() == second.next())
        #expect(first == second)
    }

    @Test func `zero seed uses the fallback state deterministically`() {
        var first = SeededRandomNumberGenerator(seed: 0)
        var second = SeededRandomNumberGenerator(seed: 0)
        #expect(first.next() == second.next())
        #expect(first.next() != 0)
    }

    @Test func `draw progress changes equality`() {
        var advanced = SeededRandomNumberGenerator(seed: 1772)
        let fresh = SeededRandomNumberGenerator(seed: 1772)
        _ = advanced.next()
        #expect(advanced != fresh)
    }
}
