import Foundation
import TrinketCore

public struct HomesteadEffects: Equatable, Hashable, Sendable {
    public var heroModifiers: [AffixModifier]
    public var companionModifiers: [AffixModifier]
    public var astralChanceBonusPercent: Int
    public var goldFindPercent: Int

    public static let zero = Self(
        heroModifiers: [],
        companionModifiers: [],
        astralChanceBonusPercent: 0,
        goldFindPercent: 0,
    )

    public init(
        heroModifiers: [AffixModifier],
        companionModifiers: [AffixModifier],
        astralChanceBonusPercent: Int,
        goldFindPercent: Int,
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
    }

    public static func from(nodeTiers: [HomesteadNodeID: Int]) -> Self {
        var effects = Self.zero
        for nodeID in HomesteadNodeID.allCases {
            let tier = nodeTiers[nodeID, default: 0]
            guard tier > 0,
                  let bonus = GameContent.homesteadNode(matching: nodeID)?.tier(tier)?.combatBonus
            else { continue }
            effects.heroModifiers.append(contentsOf: bonus.heroModifiers)
            effects.companionModifiers.append(contentsOf: bonus.companionModifiers)
            effects.astralChanceBonusPercent += bonus.astralChanceBonusPercent
            effects.goldFindPercent += bonus.goldFindPercent
        }
        return effects
    }

    public func adjustedGold(_ amount: Int) -> Int {
        guard amount > 0, goldFindPercent > 0 else { return max(0, amount) }
        return amount + (amount * goldFindPercent) / 100
    }
}
