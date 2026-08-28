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
