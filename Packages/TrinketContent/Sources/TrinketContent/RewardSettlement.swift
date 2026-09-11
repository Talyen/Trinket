import Foundation
import TrinketCore

public struct RewardSettlementInputs: Equatable, Sendable {
    public let gold: Int
    public let reservedGold: Int
    public let goldLimit: Int
    public let heroProgression: CombatantProgression
    public let companionProgression: CombatantProgression
    public let productionDate: Date

    public var goldCapacity: Int {
        max(0, goldLimit - gold - reservedGold)
    }

    public init(
        gold: Int, reservedGold: Int, goldLimit: Int,
        heroProgression: CombatantProgression, companionProgression: CombatantProgression,
        productionDate: Date,
    ) {
        self.gold = gold
        self.reservedGold = reservedGold
        self.goldLimit = goldLimit
        self.heroProgression = heroProgression
        self.companionProgression = companionProgression
        self.productionDate = productionDate
    }
}

public struct BattleRewardSettlement: Equatable, Sendable {
    public let inputs: RewardSettlementInputs
    public let award: BattleRewardAward
    public let replacementExperience: Int

    public var heroProgressionAfter: CombatantProgression {
        inputs.heroProgression.addingExperience(award.heroExperience)
    }

    public var companionProgressionAfter: CombatantProgression {
        inputs.companionProgression.addingExperience(award.companionExperience)
    }
}

public enum RewardSettlementPolicy {
    public static func settle(
        _ bonus: MysteryRewardBonus,
        inputs: RewardSettlementInputs,
        replacementExperience: Int,
    ) -> MysteryRewardBonus {
        switch bonus {
        case let .gold(amount):
            replacesGold(gains: amount, capacity: inputs.goldCapacity) ? .experience(replacementExperience) : bonus
        case let .experience(amount):
            .experience(RewardExperiencePolicy.sharedAward(amount, hero: inputs.heroProgression, companion: inputs.companionProgression))
        case .material:
            bonus
        }
    }

    public static func replacesGold(gains: Int, spending: Int = 0, capacity: Int) -> Bool {
        gains - spending > max(0, capacity)
    }
}

public enum RewardExperiencePolicy {
    public static func encounterAward(
        encounterLevel: Int, hero: CombatantProgression, companion: CombatantProgression, percent: Int = 0,
    ) -> Int {
        let base = ExperienceScaling.baseBattleAward(forPlayerLevel: max(1, encounterLevel))
        return sharedAward(CombatRounding.scaled(base, byPercent: percent), hero: hero, companion: companion)
    }

    public static func sharedAward(_ amount: Int, hero: CombatantProgression, companion: CombatantProgression) -> Int {
        min(ExperienceScaling.cappedAward(amount, for: hero), ExperienceScaling.cappedAward(amount, for: companion))
    }
}
