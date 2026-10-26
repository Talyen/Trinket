/// Selects in pool order with one integer draw. Callers own zero-weight fallback policy.
enum WeightedLootSelection {
    static func index<Pool: Collection>(
        in pool: Pool,
        totalWeight: Int,
        weight: (Pool.Element) -> Int,
        using random: inout some RandomNumberGenerator,
    ) -> Pool.Index? {
        guard totalWeight > 0 else { return nil }
        var ticket = Int.random(in: 1 ... totalWeight, using: &random)
        return pool.firstIndex { element in
            ticket -= weight(element)
            return ticket <= 0
        }
    }
}
