import Foundation
import TrinketContent
import TrinketCore

public typealias AffixPowerBumpDirection = ItemAffixPowerBumpDirection

enum AffixPowerBump {
    typealias Direction = ItemAffixPowerBumpDirection

    static func hasBumpableField(in powers: [ItemAffixPower], direction: Direction) -> Bool {
        ItemAffixPower.hasBumpableField(in: powers, direction: direction)
    }

    static func apply(
        direction: Direction,
        to powers: inout [ItemAffixPower],
        affixIDs: [String],
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> (title: String, affixIndex: Int)? {
        ItemAffixPower.applyBump(
            direction: direction,
            to: &powers,
            affixIDs: affixIDs,
            using: &randomNumberGenerator
        )
    }
}
