import Foundation

public struct PrimaryStats: Equatable, Hashable, Codable, Sendable {
    public var strength: Int
    public var agility: Int
    public var toughness: Int
    public var intellect: Int
    public var wisdom: Int

    public init(
        strength: Int = 0,
        agility: Int = 0,
        toughness: Int = 0,
        intellect: Int = 0,
        wisdom: Int = 0
    ) {
        self.strength = strength
        self.agility = agility
        self.toughness = toughness
        self.intellect = intellect
        self.wisdom = wisdom
    }

    /// Total sum of all five primary stats.
    public var total: Int {
        strength + agility + toughness + intellect + wisdom
    }
}
