import Foundation
import TrinketCore

public enum ItemDropTier: String, CaseIterable, Sendable {
    case basic
    case astral
    case trinket
    case unique

    public var id: String {
        rawValue
    }
}

public enum ItemRarityRoll {
    public static func roll(
        bossContent: Bool,
        astralChanceBonusPercent: Int = 0,
        allowsUnique: Bool = true,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> ItemDropTier {
        let uniqueBand = bossContent ? 30 : 5
        let trinketChance = bossContent ? 30 : 7
        var astralChance = bossContent ? 40 : 8
        if !bossContent {
            astralChance += max(0, min(100, astralChanceBonusPercent))
        }

        let draw = Int.random(in: 0 ..< 100, using: &randomNumberGenerator)
        if draw < uniqueBand {
            return allowsUnique ? .unique : .astral
        }
        if draw < uniqueBand + trinketChance {
            return .trinket
        }
        if draw < uniqueBand + trinketChance + astralChance {
            return .astral
        }
        return .basic
    }
}
