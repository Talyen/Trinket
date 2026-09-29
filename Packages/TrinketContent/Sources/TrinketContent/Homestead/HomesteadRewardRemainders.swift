import TrinketCore

/// Unpaid hundredths of earned Gold and Gems; production uses its own clock.
public struct HomesteadRewardRemainders: Codable, Equatable, Hashable, Sendable {
    public var gold: Int
    public var gems: Int

    public static let zero = Self()

    public init(gold: Int = 0, gems: Int = 0) {
        self.gold = min(99, max(0, gold))
        self.gems = min(99, max(0, gems))
    }

    public mutating func bonus(for resource: HomesteadResource, amount: Int, percent: Int) -> Int {
        guard amount > 0, percent > 0, resource == .gold || resource == .gems else { return 0 }
        let remainder = resource == .gold ? gold : gems
        let product = UInt(amount).multipliedFullWidth(by: UInt(percent))
        guard product.high < 100 else { return Int.max }
        let divided = UInt(100).dividingFullWidth(product)
        let fraction = Int(divided.remainder) + min(99, max(0, remainder))
        let whole = divided.quotient >= UInt(Int.max) ? Int.max : Int(divided.quotient)
        if resource == .gold {
            gold = fraction % 100
        } else {
            gems = fraction % 100
        }
        return SaturatedArithmetic.saturatingAdd(whole, fraction / 100)
    }
}
