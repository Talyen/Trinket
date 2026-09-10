import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleGoldRewardTests {
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
