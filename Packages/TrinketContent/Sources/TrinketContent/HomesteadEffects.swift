import Foundation
import TrinketCore

/// Aggregated combat and meta bonuses from the player's active Homestead node tiers.
/// Only the current tier of each node applies (higher tiers replace lower ones).
public struct HomesteadEffects: Equatable, Hashable, Sendable {
    public var heroModifiers: [AffixModifier]
    public var companionModifiers: [AffixModifier]
    public var astralChanceBonusPercent: Int
    public var goldFindPercent: Int

    public static let zero = HomesteadEffects(
        heroModifiers: [],
        companionModifiers: [],
        astralChanceBonusPercent: 0,
        goldFindPercent: 0
    )

    public init(
        heroModifiers: [AffixModifier],
        companionModifiers: [AffixModifier],
        astralChanceBonusPercent: Int,
        goldFindPercent: Int
    ) {
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.astralChanceBonusPercent = astralChanceBonusPercent
        self.goldFindPercent = goldFindPercent
    }

    public static func from(nodeTiers: [HomesteadNodeID: Int]) -> HomesteadEffects {
        var effects = HomesteadEffects.zero
        for nodeID in HomesteadNodeID.allCases {
            let tier = nodeTiers[nodeID, default: 0]
            guard tier > 0 else { continue }
            apply(nodeID: nodeID, tier: tier, to: &effects)
        }
        return effects
    }

    public func adjustedGold(_ amount: Int) -> Int {
        guard amount > 0, goldFindPercent > 0 else { return max(0, amount) }
        return amount + (amount * goldFindPercent) / 100
    }

    private static func apply(nodeID: HomesteadNodeID, tier: Int, to effects: inout HomesteadEffects) {
        switch nodeID {
        case .wheatField:
            effects.companionModifiers.append(.maximumHealth(tierValue(tier, values: [2, 4, 6])))
        case .herbGarden:
            effects.heroModifiers.append(.healthRestored(tierValue(tier, values: [1, 2, 3])))
        case .chickenCoop:
            effects.heroModifiers.append(.strength(tierValue(tier, values: [1, 2, 3])))
        case .pasture:
            effects.companionModifiers.append(.toughness(tierValue(tier, values: [1, 2, 3])))
        case .culinaryArts:
            effects.heroModifiers.append(.maximumHealth(tierValue(tier, values: [2, 4, 6])))
        case .blacksmithForge:
            effects.heroModifiers.append(
                .damageDealt(.physical, tierValue(tier, values: [1, 2, 3]))
            )
        case .woolTailoring:
            effects.heroModifiers.append(
                .damageTakenFlat(.freeze, tierValue(tier, values: [1, 2, 3]))
            )
        case .alchemyLab:
            effects.heroModifiers.append(
                .damageDealt(.poison, tierValue(tier, values: [1, 2, 3]))
            )
        case .botanicalDistillation:
            effects.heroModifiers.append(
                .damageDealt(.nature, tierValue(tier, values: [1, 2, 3]))
            )
        case .crystalGarden:
            effects.heroModifiers.append(.intellect(tierValue(tier, values: [1, 2, 3])))
        case .runesmithWorkshop:
            let percent = Double(tierValue(tier, values: [5, 10, 15])) / 100
            effects.heroModifiers.append(.manaCostReductionPercent(percent))
        case .hunterLodge:
            effects.heroModifiers.append(.companionDamageDealt(tierValue(tier, values: [1, 2, 3])))
        case .agilityTraining:
            effects.companionModifiers.append(.agility(tierValue(tier, values: [1, 2, 3])))
        case .detectMagic:
            effects.astralChanceBonusPercent = tierValue(tier, values: [5, 10, 15])
        case .wishingWell:
            effects.goldFindPercent = tierValue(tier, values: [5, 10, 15])
        }
    }

    private static func tierValue(_ tier: Int, values: [Int]) -> Int {
        let index = min(max(tier, 1), values.count) - 1
        return values[index]
    }
}
