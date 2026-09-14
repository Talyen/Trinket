import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleGoldRewardTests {
    @Test @MainActor func `defeat experience persists both recipients without other rewards`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let before = store.currentSave
        let settlement = BattleRewardPlan(
            stageGold: 100, goldFindPercent: 100, goldOverflowExperience: 100,
            heroExperience: 40, companionExperience: 30, materials: [], items: [],
        ).settleDefeat(
            progress: .init(remainingHealth: 10, maximumHealth: 100),
            inputs: RewardSettlementInputs(save: before, hero: hero, companion: companion),
        )
        try #require(store.persistBatch(logging: "Save defeat experience") { save in
            BattleExperienceReward.apply(settlement, hero: hero, companion: companion, save: &save)
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.progression(for: hero) == settlement.heroProgressionAfter)
        #expect(reloaded.roster.progression(for: companion) == settlement.companionProgressionAfter)
        #expect(reloaded.roster.gold == before.roster.gold)
        #expect(reloaded.currentSave.inventory == before.inventory)
        #expect(reloaded.currentSave.journey == before.journey)
    }

    @Test @MainActor func `victory persists positive battle gold without reducing wallet`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try #require(store.persistBatch(logging: "Seed battle wallet") { save in
            save.roster.gold = 100
            let hero = save.roster.activeHero
            let companion = save.roster.activeCompanion
            let plan = BattleRewardPlan(
                stageGold: 5, goldFindPercent: 0,
                heroExperience: 0, companionExperience: 0, materials: [], items: [],
            )
            let settlement = plan.settle(
                battleGold: .init(gained: 3),
                inputs: RewardSettlementInputs(save: save, hero: hero, companion: companion),
            )
            VictoryRewardApplier.apply(settlement, hero: hero, companion: companion, save: &save)
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 108)
    }
}
