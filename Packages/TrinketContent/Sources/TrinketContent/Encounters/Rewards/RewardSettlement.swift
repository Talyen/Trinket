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
        max(0, SaturatedArithmetic.saturatingSub(
            SaturatedArithmetic.saturatingSub(goldLimit, gold), reservedGold,
        ))
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
            let overflow = goldOverflow(gains: amount, spending: 0, capacity: inputs.goldCapacity)
            if overflow == 0 {
                return bonus
            }
            let experience = overflowExperience(replacementExperience, overflow: overflow, gains: amount)
            if overflow >= amount {
                return .experience(experience)
            }
            return .goldAndExperience(
                gold: amount - overflow, experience: experience,
                nominalGold: amount, fullOverflowExperience: replacementExperience,
            )
        case .goldAndExperience:
            return bonus
        case let .experience(amount):
            return .experience(RewardExperiencePolicy.sharedAward(
                amount,
                hero: inputs.heroProgression,
                companion: inputs.companionProgression,
            ))
        case .material:
            return bonus
        }
    }

    public static func replacesGold(gains: Int, spending: Int, capacity: Int) -> Bool {
        SaturatedArithmetic.saturatingSub(gains, spending) > max(0, capacity)
    }

    public static func goldOverflow(gains: Int, spending: Int, capacity: Int) -> Int {
        max(0, SaturatedArithmetic.saturatingSub(
            SaturatedArithmetic.saturatingSub(max(0, gains), max(0, spending)), max(0, capacity),
        ))
    }

    public static func overflowExperience(_ amount: Int, overflow: Int, gains: Int) -> Int {
        guard amount > 0, overflow > 0, gains > 0 else { return 0 }
        let boundedOverflow = min(overflow, gains)
        if boundedOverflow == gains {
            return amount
        }
        let product = UInt(amount).multipliedFullWidth(by: UInt(boundedOverflow))
        return Int(UInt(gains).dividingFullWidth(product).quotient)
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
