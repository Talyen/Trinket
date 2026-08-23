import Foundation
import TrinketCore

/// Outcome of a reward roll: the scarcity ladder every content class shares.
public enum ItemDropTier: String, CaseIterable, Sendable {
    case basic
    case astral
    case trinket
    case unique

    public var id: String {
        rawValue
    }
}

/// Unified drop-rate model across all content classes.
///
/// Normal content holds a 20% special budget above Basic; Boss content plays
/// with a full 100% budget and never yields Basic. The three special tiers sit
/// in narrow bands (Astral > Trinket > Unique scarcity). The Homestead Astral
/// bonus widens only the Astral band by shifting Basic; Trinket and Unique
/// shares are fixed. When shops disallow Uniques their band folds into Astral.
public enum ItemRarityRoll {
    public static func roll(
        bossContent: Bool,
        astralChanceBonusPercent: Int = 0,
        allowsUnique: Bool = true,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemDropTier {
        let uniqueChance = bossContent ? 30 : (allowsUnique ? 5 : 0)
        let trinketChance = bossContent ? 30 : 7
        var astralChance = bossContent ? 40 : 8
        if !bossContent {
            astralChance += max(0, min(100, astralChanceBonusPercent))
            if !allowsUnique {
                astralChance += 5
            }
        }

        let draw = Int.random(in: 0 ..< 100, using: &randomNumberGenerator)
        if draw < uniqueChance {
            return .unique
        }
        if draw < uniqueChance + trinketChance {
            return .trinket
        }
        if draw < uniqueChance + trinketChance + astralChance {
            return .astral
        }
        return .basic
    }
}
