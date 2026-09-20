import Foundation
import TrinketCore

public struct HomesteadEffects: Equatable, Hashable, Sendable {
    public var heroModifiers: [AffixModifier]
    public var companionModifiers: [AffixModifier]
    public var astralChanceBonusPercent: Int
    public var goldFindPercent: Int
    public var goldFindFlat: Int
    public var experienceBonus: Int
    public var gemsFindBonus: Int

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
        goldFindFlat: Int = 0,
        experienceBonus: Int = 0,
        gemsFindBonus: Int = 0,
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.goldFindFlat = goldFindFlat
        self.experienceBonus = experienceBonus
        self.gemsFindBonus = gemsFindBonus
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
            effects.goldFindFlat += bonus.goldFindFlat
            effects.experienceBonus += bonus.experienceBonus
            effects.gemsFindBonus += bonus.gemsFindBonus
        }
        return effects
    }

    public func adjustedMaterials(_ amounts: [ResourceAmount]) -> [ResourceAmount] {
        var applied = false
        return amounts.map { amount in
            guard amount.resource == .gems, amount.quantity > 0, !applied else { return amount }
            applied = true
            return ResourceAmount(.gems, amount.quantity + gemsFindBonus)
        }
    }

    public func adjustedGold(_ amount: Int) -> Int {
        guard amount > 0 else { return 0 }
        return amount + (amount * goldFindPercent) / 100 + goldFindFlat
    }
}
