import Testing
import TrinketCore

struct SeededRandomNumberGeneratorTests {
    @Test func `seeded battles preserve the historical draw sequence`() {
        var generator = SeededRandomNumberGenerator(seed: 1772)
        let expected: [UInt64] = [
            7731454660870130891,
            10357557263425746430,
            15960892827339718901,
            16233710992148412256,
        ]
        #expect(expected.map { _ in generator.next() } == expected)
    }

    @Test func `draw progress changes equality`() {
        var advanced = SeededRandomNumberGenerator(seed: 1772)
        let fresh = SeededRandomNumberGenerator(seed: 1772)
        _ = advanced.next()
        #expect(advanced != fresh)
    }

    @Test func `zero seed fallback shares sequence but not equality`() {
        var fromZero = SeededRandomNumberGenerator(seed: 0)
        var fromFallback = SeededRandomNumberGenerator(seed: 0x4D59_5DF4_D0F3_3173)
        #expect(fromZero != fromFallback)
        #expect(fromZero.next() == fromFallback.next())
        #expect(fromZero.next() == fromFallback.next())
    }
}
