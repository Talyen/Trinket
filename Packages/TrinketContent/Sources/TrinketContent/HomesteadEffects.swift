import Foundation
import TrinketCore

/// Aggregated combat and meta bonuses from the player's active Homestead node tiers.
/// Only the current tier of each node applies (higher tiers replace lower ones).
public struct HomesteadEffects: Equatable, Hashable, Sendable {
    public var heroModifiers: [AffixModifier]
    public var companionModifiers: [AffixModifier]
    public var astralChanceBonusPercent: Int
    public var goldFindPercent: Int

    public static let zero = Self(
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

    public static func from(nodeTiers: [HomesteadNodeID: Int]) -> Self {
        var effects = Self.zero
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

    private static func apply(nodeID: HomesteadNodeID, tier: Int, to effects: inout Self) {
        switch nodeID {
        case .wheatField:
            appendUniversal(
                .maximumHealth(tierValue(tier, values: [4, 8, 12, 16])),
                to: &effects
            )
        case .herbGarden:
            appendUniversal(
                .healthRestored(tierValue(tier, values: [1, 2, 3, 4])),
                to: &effects
            )
        case .chickenCoop:
            appendUniversal(
                .strength(tierValue(tier, values: [2, 4, 6, 8])),
                to: &effects
            )
        case .pasture:
            appendUniversal(
                .toughness(tierValue(tier, values: [2, 4, 6, 8])),
                to: &effects
            )
        case .culinaryArts:
            let percent = Double(tierValue(tier, values: [10, 20, 30, 40])) / 100
            appendUniversal(.damageTakenPercent(.burn, percent), to: &effects)
        case .blacksmithForge:
            appendUniversal(
                .damageDealt(.physical, tierValue(tier, values: [1, 2, 3, 4])),
                to: &effects
            )
        case .woolTailoring:
            let percent = Double(tierValue(tier, values: [15, 30, 40, 50])) / 100
            appendUniversal(.damageTakenPercent(.freeze, percent), to: &effects)
        case .alchemyLab:
            let dealtPercent = Double(tierValue(tier, values: [5, 10, 15, 20])) / 100
            let dealtModifier = AffixModifier.poisonDamageDealtPercent(dealtPercent)
            effects.heroModifiers.append(dealtModifier)
            effects.companionModifiers.append(dealtModifier)

            let takenPercent = Double(tierValue(tier, values: [10, 20, 30, 40])) / 100
            let takenModifier = AffixModifier.damageTakenPercent(.poison, takenPercent)
            effects.heroModifiers.append(takenModifier)
            effects.companionModifiers.append(takenModifier)
        case .crystalGarden:
            appendUniversal(
                .maximumMana(tierValue(tier, values: [2, 4, 6, 8])),
                to: &effects
            )
        case .runesmithWorkshop:
            let amount = tierValue(tier, values: [1, 2, 3, 4])
            for keyword in [Keyword.burn, .freeze, .holy] {
                appendUniversal(.damageDealt(keyword, amount), to: &effects)
            }
        case .hunterLodge:
            effects.heroModifiers.append(.companionDamageDealt(tierValue(tier, values: [1, 2, 3, 4])))
        case .agilityTraining:
            effects.companionModifiers.append(.agility(tierValue(tier, values: [2, 4, 6, 8])))
        case .moonlitSanctum:
            effects.astralChanceBonusPercent = tierValue(tier, values: [5, 10, 15, 20])
        case .wishingWell:
            effects.goldFindPercent = tierValue(tier, values: [5, 10, 15, 20])
        }
    }

    private static func tierValue(_ tier: Int, values: [Int]) -> Int {
        let index = min(max(tier, 1), values.count) - 1
        return values[index]
    }

    private static func appendUniversal(_ modifier: AffixModifier, to effects: inout Self) {
        effects.heroModifiers.append(modifier)
        effects.companionModifiers.append(modifier)
    }
}
