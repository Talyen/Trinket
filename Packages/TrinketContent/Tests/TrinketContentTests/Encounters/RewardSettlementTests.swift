import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct RewardSettlementTests {
    private func inputs(
        gold: Int = 0,
        goldLimit: Int = 100,
        heroLevel: Int = 5,
        companionLevel: Int = 5,
    ) -> RewardSettlementInputs {
        RewardSettlementInputs(
            gold: gold,
            reservedGold: 0,
            goldLimit: goldLimit,
            heroProgression: .at(level: heroLevel),
            companionProgression: .at(level: companionLevel),
            productionDate: Date(timeIntervalSince1970: 0),
        )
    }

    @Test(arguments: [(80, 10), (50, 25), (10, 45), (42, 29), (100, 0), (99, 0)])
    func `defeat experience uses peak health and rounds down`(remaining: Int, expected: Int) {
        let plan = BattleRewardPlan(
            stageGold: 100, goldFindPercent: 100, goldOverflowExperience: 100,
            heroExperience: 100, companionExperience: 51,
            materials: [], items: [],
        )
        let settlement = plan.settleDefeat(
            progress: .init(remainingHealth: remaining, maximumHealth: 100),
            inputs: inputs(gold: 100),
        )
        #expect(settlement.award.heroExperience == expected)
        #expect(settlement.award.companionExperience == 51 * (100 - remaining) / 200)
        #expect(settlement.award.goldDelta == 0)
        #expect(settlement.award.materials.isEmpty)
        #expect(settlement.award.items.isEmpty)
        #expect(settlement.replacementExperience == 0)
    }

    @Test func `defeat experience retains zero eligibility and progression caps`() {
        let plan = BattleRewardPlan(
            stageGold: 100, goldFindPercent: 0, goldOverflowExperience: 100,
            heroExperience: 0, companionExperience: 100000, materials: [], items: [],
        )
        let settlement = plan.settleDefeat(
            progress: .init(remainingHealth: 1, maximumHealth: 100),
            inputs: inputs(heroLevel: 1, companionLevel: 1),
        )
        #expect(settlement.award.heroExperience == 0)
        #expect(settlement.award.companionExperience == ExperienceScaling.cappedAward(49500, for: .at(level: 1)))
    }

    @Test func `defeat experience avoids overflowing before division`() {
        let progress = BattleDefeatProgress(remainingHealth: 1, maximumHealth: Int.max)
        #expect(progress.experienceAward(from: Int.max) == (Int.max - 1) / 2)
        #expect(progress.experienceAward(from: Int.min) == 0)
        #expect(BattleDefeatProgress(remainingHealth: 0, maximumHealth: 3).experienceAward(from: 5) == 2)
    }

    @Test func `defeat experience retains launch-baked bonuses`() {
        let progress = BattleDefeatProgress(remainingHealth: 50, maximumHealth: 100)
        let base = BattleRewardPlan(
            stageGold: 0, goldFindPercent: 0,
            heroExperience: 100, companionExperience: 100,
            materials: [], items: [],
        ).settleDefeat(progress: progress, inputs: inputs())
        let bonused = BattleRewardPlan(
            stageGold: 0, goldFindPercent: 0,
            heroExperience: 150, companionExperience: 150,
            materials: [], items: [],
        ).settleDefeat(progress: progress, inputs: inputs())
        #expect(base.award.heroExperience == 25)
        #expect(bonused.award.heroExperience == 37)
        #expect(bonused.award.companionExperience == 37)
    }

    @Test func `encounter plans keep victory bonuses out of defeat and suppress claimed loot`() {
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [.library: 4, .wishingWell: 2])
        let plan = BattleRewardPlan.forEncounter(
            party: (.at(level: 1), .at(level: 1)), highestLevels: (1, 1),
            encounterLevel: 1, homestead: homestead,
            stageGold: 10, materials: [ResourceAmount(.wood, 3)], items: [],
            experienceEarnedPercent: 30, victoryOnlyExperienceBonusPercent: 50,
        )
        // L1 normal XP is 3: Library +20%, shared +30%, victory-only +50%.
        #expect(plan.heroExperience == 6)
        #expect(plan.companionExperience == 6)
        #expect(plan.defeatHeroExperience == 5)
        #expect(plan.defeatCompanionExperience == 5)
        let defeat = plan.settleDefeat(
            progress: .init(remainingHealth: 50, maximumHealth: 100),
            inputs: inputs(heroLevel: 1, companionLevel: 1),
        )
        #expect(defeat.award.heroExperience == 1)
        #expect(defeat.award.companionExperience == 1)

        let claimed = BattleRewardPlan.forEncounter(
            party: (.at(level: 1), .at(level: 1)), highestLevels: (1, 1),
            encounterLevel: 1, homestead: homestead,
            stageGold: 10, materials: [ResourceAmount(.wood, 3)], items: [],
            rewardsAlreadyClaimed: true,
        )
        #expect(claimed.heroExperience == 0)
        #expect(claimed.defeatHeroExperience == 0)
        #expect(claimed.materials.isEmpty)
        // Replays still retain earned combat Gold and its Homestead bonus.
        let replay = claimed.resolve(battleGold: .init(gained: 10))
        #expect(replay.stageGold == 0)
        #expect(replay.goldDelta == 11)
    }

    @Test func `encounter plans incorporate flat experience bonuses into awards`() {
        let homestead = PlayerHomesteadState(resources: [:], nodeTiers: [:])
        let plan = BattleRewardPlan.forEncounter(
            party: (.at(level: 1), .at(level: 1)), highestLevels: (1, 1),
            encounterLevel: 1, homestead: homestead,
            stageGold: 0, materials: [], items: [],
            flatExperienceBonus: 5,
        )
        #expect(plan.heroExperience == 8)
        #expect(plan.companionExperience == 8)
        #expect(plan.defeatHeroExperience == 8)
        #expect(plan.defeatCompanionExperience == 8)
    }

    @Test func `victory Gold Talent adds to Homestead bonus before spending and retains fractions`() {
        let plan = BattleRewardPlan.forEncounter(
            party: (.at(level: 1), .at(level: 1)), highestLevels: (1, 1),
            encounterLevel: 1,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wishingWell: 2]),
            stageGold: 7, materials: [], items: [], victoryGoldBonusPercent: 10,
        )
        let goldFlow = BattleGoldFlow(gained: 6, spent: 4)
        let first = plan.resolve(battleGold: goldFlow)
        #expect(first.goldDelta == 11)
        let second = plan.resolve(battleGold: goldFlow, rewardRemainders: first.rewardRemainders)
        #expect(second.goldDelta == 12)
        let defeat = plan.settleDefeat(
            progress: .init(remainingHealth: 0, maximumHealth: 100), inputs: inputs(),
        )
        #expect(defeat.award.goldDelta == 0)
        #expect(defeat.award.rewardRemainders == inputs().rewardRemainders)
    }

    @Test func `resolve splits stage gold from battle gains`() {
        let plan = BattleRewardPlan(
            stageGold: 100,
            goldFindPercent: 0,
            heroExperience: 10,
            companionExperience: 10,
            materials: [],
            items: [],
        )
        let award = plan.resolve(battleGold: BattleGoldFlow(gained: 50, spent: 5))
        #expect(award.stageGold == 100)
        #expect(award.battleGold == 45)
        #expect(award.goldDelta == 145)
    }

    @Test func `battle gold and flat bonus saturate without losing spending`() {
        let plan = BattleRewardPlan(
            stageGold: Int.max - 1, goldFindPercent: 0, goldFindFlat: 10,
            heroExperience: 0, companionExperience: 0, materials: [], items: [],
        )
        let award = plan.resolve(battleGold: .init(gained: Int.max, spent: Int.max))
        #expect(award.stageGold == Int.max - 1)
        #expect(award.battleGold == 1 - Int.max)
        #expect(award.goldDelta == 0)
        #expect(award.goldGained == Int.max)

        let unspent = plan.resolve(battleGold: .init(gained: Int.max))
        #expect(unspent.goldDelta == Int.max)
        #expect(unspent.goldGained == Int.max)
    }

    @Test func `full wallet replaces gold with overflow experience`() {
        let plan = BattleRewardPlan(
            stageGold: 10,
            goldFindPercent: 0,
            goldOverflowExperience: 42,
            heroExperience: 10,
            companionExperience: 10,
            materials: [],
            items: [],
        )
        let settlement = plan.settle(
            battleGold: BattleGoldFlow(),
            inputs: inputs(gold: 100, goldLimit: 100),
        )
        #expect(settlement.award.stageGold == 0)
        #expect(settlement.award.goldDelta == 0)
        #expect(settlement.replacementExperience == 42)
        #expect(settlement.award.heroExperience > 10)
    }

    @Test func `partial gold overflow grants fitting gold and proportional experience`() {
        let plan = BattleRewardPlan(
            stageGold: 20, goldFindPercent: 0, goldOverflowExperience: 40,
            heroExperience: 2, companionExperience: 2, materials: [], items: [],
        )
        let settlement = plan.settle(battleGold: .init(), inputs: inputs(gold: 90, goldLimit: 100))
        #expect(settlement.award.goldGained == 10)
        #expect(settlement.award.goldDelta == 10)
        #expect(settlement.replacementExperience == 20)
        #expect(settlement.award.heroExperience == 22)
        #expect(RewardSettlementPolicy.overflowExperience(Int.max, overflow: Int.max / 2, gains: Int.max) > 0)
    }

    @Test func `overflow compensation is capped after saturating`() {
        let plan = BattleRewardPlan(
            stageGold: 1, goldFindPercent: 0, goldOverflowExperience: Int.max,
            heroExperience: Int.max, companionExperience: Int.max,
            materials: [], items: [],
        )
        let settlement = plan.settle(battleGold: .init(), inputs: inputs(gold: 100, goldLimit: 100, heroLevel: 1, companionLevel: 1))
        #expect(settlement.award.goldDelta == 0)
        #expect(settlement.award.heroExperience == 30)
        #expect(settlement.award.companionExperience == 30)
        #expect(settlement.replacementExperience == Int.max)
    }

    @Test func `capacity and gold overflow saturate`() {
        let extreme = RewardSettlementInputs(
            gold: Int.min, reservedGold: Int.min, goldLimit: Int.max,
            heroProgression: .initial, companionProgression: .initial,
            productionDate: Date(timeIntervalSince1970: 0),
        )
        #expect(extreme.goldCapacity == Int.max)
        #expect(RewardSettlementPolicy.goldOverflow(gains: Int.max, spending: Int.max, capacity: 0) == 0)
        #expect(RewardSettlementPolicy.goldOverflow(gains: Int.max, spending: 0, capacity: 0) == Int.max)
    }

    @Test func `shared award is capped by the lower-level partner`() {
        let capped = RewardExperiencePolicy.sharedAward(
            10000,
            hero: .at(level: 20),
            companion: .at(level: 1),
        )
        #expect(capped == ExperienceScaling.cappedAward(10000, for: .at(level: 1)))
    }
}
