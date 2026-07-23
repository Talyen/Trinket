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
            effects.companionModifiers.append(.maximumHealth(tierValue(tier, values: [4, 8, 12, 16])))
        case .herbGarden:
            effects.heroModifiers.append(.healthRestored(tierValue(tier, values: [1, 2, 3, 4])))
        case .chickenCoop:
            effects.heroModifiers.append(.strength(tierValue(tier, values: [2, 4, 6, 8])))
        case .pasture:
            effects.companionModifiers.append(.toughness(tierValue(tier, values: [2, 4, 6, 8])))
        case .culinaryArts:
            effects.heroModifiers.append(.maximumHealth(tierValue(tier, values: [4, 8, 12, 16])))
        case .blacksmithForge:
            effects.heroModifiers.append(
                .damageDealt(.physical, tierValue(tier, values: [1, 2, 3, 4]))
            )
        case .woolTailoring:
            let percent = Double(tierValue(tier, values: [10, 20, 30, 40])) / 100
            effects.heroModifiers.append(.damageTakenPercent(.freeze, percent))
        case .alchemyLab:
            let percent = Double(tierValue(tier, values: [5, 10, 15, 20])) / 100
            effects.heroModifiers.append(.poisonDamageDealtPercent(percent))
        case .botanicalDistillation:
            let percent = Double(tierValue(tier, values: [10, 20, 30, 40])) / 100
            let modifier = AffixModifier.damageTakenPercent(.poison, percent)
            effects.heroModifiers.append(modifier)
            effects.companionModifiers.append(modifier)
        case .crystalGarden:
            effects.heroModifiers.append(.intellect(tierValue(tier, values: [2, 4, 6, 8])))
        case .runesmithWorkshop:
            let amount = tierValue(tier, values: [1, 2, 3, 4])
            effects.heroModifiers.append(contentsOf: [
                .damageDealt(.burn, amount),
                .damageDealt(.freeze, amount),
                .damageDealt(.holy, amount)
            ])
        case .hunterLodge:
            effects.heroModifiers.append(.companionDamageDealt(tierValue(tier, values: [1, 2, 3, 4])))
        case .agilityTraining:
            effects.companionModifiers.append(.agility(tierValue(tier, values: [2, 4, 6, 8])))
        case .detectMagic:
            effects.astralChanceBonusPercent = tierValue(tier, values: [5, 10, 15, 20])
        case .wishingWell:
            effects.goldFindPercent = tierValue(tier, values: [5, 10, 15, 20])
        }
    }

    private static func tierValue(_ tier: Int, values: [Int]) -> Int {
        let index = min(max(tier, 1), values.count) - 1
        return values[index]
    }
}
