import Foundation
import TrinketCore

/// Shared Astral rarity rolls for shops, mystery events, and labyrinth drops.
public enum ItemRarityRoll {
    public static func roll(
        baseAstralChancePercent: Int,
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Rarity {
        let chance = min(100, max(0, baseAstralChancePercent + astralChanceBonusPercent))
        return Int.random(in: 0 ... 99, using: &randomNumberGenerator) < chance ? .astral : .basic
    }
}
