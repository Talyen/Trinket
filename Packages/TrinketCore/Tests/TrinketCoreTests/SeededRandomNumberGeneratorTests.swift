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
}
