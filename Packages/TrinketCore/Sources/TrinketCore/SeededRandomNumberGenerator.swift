/// Deterministic LCG for replays and tests. Synthesized `Equatable` intentionally
/// includes draw progress (`state`), so a used generator never equals a fresh one
/// with the same seed. Equality is lineage, not future-sequence equality: the
/// zero-seed fallback maps `seed == 0` to a fixed non-zero state, so
/// `init(seed: 0)` and `init(seed: <fallback>)` share a future sequence while
/// comparing unequal.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Equatable, Sendable {
    public let seed: UInt64

    private var state: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        state = seed == 0 ? 0x4D59_5DF4_D0F3_3173 : seed
    }

    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
