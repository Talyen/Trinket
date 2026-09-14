public struct BattleDefeatProgress: Equatable, Hashable, Sendable {
    public let remainingHealth: Int
    public let maximumHealth: Int

    public init(remainingHealth: Int, maximumHealth: Int) {
        self.maximumHealth = max(1, maximumHealth)
        self.remainingHealth = min(max(0, remainingHealth), self.maximumHealth)
    }

    public var depletedFraction: Double {
        Double(maximumHealth - remainingHealth) / Double(maximumHealth)
    }

    public func experienceAward(from normalExperience: Int) -> Int {
        max(0, normalExperience) * (maximumHealth - remainingHealth) / maximumHealth / 2
    }
}
