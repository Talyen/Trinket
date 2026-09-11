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

    @Test func `shared award is capped by the lower-level partner`() {
        let capped = RewardExperiencePolicy.sharedAward(
            10000,
            hero: .at(level: 20),
            companion: .at(level: 1),
        )
        #expect(capped == ExperienceScaling.cappedAward(10000, for: .at(level: 1)))
    }
}
