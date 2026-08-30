enum BattleChance {
    static func succeeds(
        probability: Double,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Bool {
        guard probability > 0 else { return false }
        guard probability < 1 else { return true }
        return Double.random(in: 0 ..< 1, using: &randomNumberGenerator) < probability
    }
}
