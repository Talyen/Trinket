import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleGoldRewardTests {
    @Test func `minimum integer Gold debit spends the wallet without overflowing`() {
        var save = PlayerSave.testSeed
        save.roster.gold = 20
        let before = save.homestead
        #expect(save.applyGoldDelta(Int.min, at: before.lastProductionAt) == -20)
        #expect(save.roster.gold == 0)
        #expect(save.homestead == before)
    }

    @Test @MainActor func `duplicate item consolation saturates a maximum Gold reward across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let item = try #require(GameContent.uniqueItems.first)
        try #require(store.persistFixtureBatch(logging: "Seed duplicate reward item") { save in
            save.inventory.items = [item]
        })
        let contracts = store.currentSave.contracts
        try #require(store.persistFixtureBatch(logging: "Grant maximum Gold reward") { save in
            VictoryRewardApplier.grantVictoryRewards(
                party: (save.roster.activeHero, save.roster.activeCompanion),
                encounterLevel: 1,
                stageGold: Int.max,
                grantsCombatExperience: false,
                materialRewards: [],
                item: item,
                save: &save,
                recordReceipt: { _ in },
            )
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == PlayerRosterState.maxGoldBalance)
        #expect(reloaded.inventory.items == [item])
        #expect(reloaded.currentSave.contracts == contracts)
    }

    @Test @MainActor func `defeat experience persists both recipients without other rewards`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let before = store.currentSave
        let plan = BattleRewardPlan(
            stageGold: 100, goldFindPercent: 100, goldOverflowExperience: 100,
            heroExperience: 40, companionExperience: 30, materials: [], items: [],
        )
        let settlement = plan.settleDefeat(
            progress: .init(remainingHealth: 10, maximumHealth: 100),
            inputs: RewardSettlementInputs(save: before, hero: hero, companion: companion),
        )
        let claim = store.prepareBattleRewardClaim(at: nil, heroID: hero.id, companionID: companion.id)
        guard case .committed = store.claimDefeatExperience(claim, award: settlement) else {
            Issue.record("Expected defeat experience to commit")
            return
        }
        // A duplicate delivery or conflicting victory cannot use the same claim.
        let duplicate = plan.settleDefeat(
            progress: .init(remainingHealth: 10, maximumHealth: 100),
            inputs: RewardSettlementInputs(save: store.currentSave, hero: hero, companion: companion),
        )
        guard case .rejected = store.claimDefeatExperience(claim, award: duplicate),
              case .rejected = store.completeBattle(claim, award: duplicate, enemyEncounterLevel: nil) else {
            Issue.record("A consumed claim granted another outcome")
            return
        }
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
        try #require(store.persistFixtureBatch(logging: "Seed battle wallet") { save in
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
            VictoryRewardApplier.apply(settlement, hero: hero, companion: companion, save: &save, recordReceipt: { _ in })
        })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 108)
    }
}
