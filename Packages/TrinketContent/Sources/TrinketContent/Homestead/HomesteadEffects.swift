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
    public var gemsFindPercent: Int
    public var experienceBonusPercent: Int

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
        gemsFindPercent: Int = 0,
        experienceBonusPercent: Int = 0,
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.goldFindFlat = goldFindFlat
        self.experienceBonus = experienceBonus
        self.gemsFindBonus = gemsFindBonus
        self.gemsFindPercent = gemsFindPercent
        self.experienceBonusPercent = experienceBonusPercent
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
            effects.gemsFindPercent += bonus.gemsFindPercent
            effects.experienceBonusPercent += bonus.experienceBonusPercent
        }
        return effects
    }

    public func adjustedMaterials(_ amounts: [ResourceAmount]) -> [ResourceAmount] {
        var remainders = HomesteadRewardRemainders.zero
        return adjustedMaterials(amounts, remainders: &remainders)
    }

    public func adjustedMaterials(
        _ amounts: [ResourceAmount], remainders: inout HomesteadRewardRemainders,
    ) -> [ResourceAmount] {
        let gems = amounts.filter { $0.resource == .gems && $0.quantity > 0 }
            .reduce(0) { SaturatedArithmetic.saturatingAdd($0, $1.quantity) }
        let bonus = SaturatedArithmetic.saturatingAdd(
            gemsFindBonus, remainders.bonus(for: .gems, amount: gems, percent: gemsFindPercent),
        )
        var applied = false
        return amounts.map { amount in
            guard amount.resource == .gems, amount.quantity > 0, !applied else { return amount }
            applied = true
            return ResourceAmount(.gems, SaturatedArithmetic.saturatingAdd(amount.quantity, bonus))
        }
    }

    public func adjustedGold(_ amount: Int) -> Int {
        var remainders = HomesteadRewardRemainders.zero
        return adjustedGold(amount, remainders: &remainders)
    }

    public func adjustedGold(_ amount: Int, remainders: inout HomesteadRewardRemainders) -> Int {
        guard amount > 0 else { return 0 }
        if goldFindPercent < 0 {
            return SaturatedArithmetic.saturatingAdd(CombatRounding.scaled(amount, byPercent: goldFindPercent), goldFindFlat)
        }
        return SaturatedArithmetic.saturatingAdd(
            amount, SaturatedArithmetic.saturatingAdd(
                goldFindFlat, remainders.bonus(for: .gold, amount: amount, percent: goldFindPercent),
            ),
        )
    }
}
