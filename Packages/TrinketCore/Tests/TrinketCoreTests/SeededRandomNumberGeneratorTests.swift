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

    @Test func `different seeds diverge`() {
        var first = SeededRandomNumberGenerator(seed: 1)
        var second = SeededRandomNumberGenerator(seed: 2)
        #expect(first.next() != second.next())
    }

    @Test func `long sequences replay deterministically`() {
        var first = SeededRandomNumberGenerator(seed: 99)
        var second = SeededRandomNumberGenerator(seed: 99)
        for _ in 0 ..< 100 {
            #expect(first.next() == second.next())
        }
        #expect(first == second)
    }

    @Test func `zero seed fallback shares sequence but not equality`() {
        var fromZero = SeededRandomNumberGenerator(seed: 0)
        var fromFallback = SeededRandomNumberGenerator(seed: 0x4D59_5DF4_D0F3_3173)
        #expect(fromZero != fromFallback)
        #expect(fromZero.next() == fromFallback.next())
        #expect(fromZero.next() == fromFallback.next())
    }

    @Test func `works through the RandomNumberGenerator protocol`() {
        var generator = SeededRandomNumberGenerator(seed: 7)
        let first = Int.random(in: 0 ..< 1000, using: &generator)
        var replay = SeededRandomNumberGenerator(seed: 7)
        #expect(Int.random(in: 0 ..< 1000, using: &replay) == first)
    }
}
