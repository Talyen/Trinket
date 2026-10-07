import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeContractRefreshTests {
    @Test @MainActor func `two board refreshes preserve independent earned rewards across reload`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        base.contracts.ensureBoard()
        base.contracts.earnRefresh()
        let hero = base.roster.activeHero
        let beforeXP = base.roster.progression(for: hero).totalEarnedExperience
        var first = base
        var second = base
        let refreshedFirst = first.contracts.refresh()
        let refreshedSecond = second.contracts.refresh()
        #expect(refreshedFirst && refreshedSecond)
        first.roster.grantGold(7)
        second.roster.grantGold(11)
        _ = first.roster.grantExperience(7, to: hero)
        _ = second.roster.grantExperience(11, to: hero)

        for preferIncoming in [true, false] {
            let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
            let context = try PersistenceTestContext()
            try SaveTestSupport.writeRoot(merged, to: context.storeURL())
            let restored = try context.makeSaveStore()
            #expect(restored.roster.gold == 28)
            #expect(restored.roster.progression(for: hero).totalEarnedExperience == beforeXP + 18)
            #expect(restored.contracts.offers.count == 3)
        }
    }

    @Test @MainActor func `matching Contract wins still grant one payout after refresh and reload`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        base.contracts.ensureBoard()
        let offer = try #require(base.contracts.offer(for: .easy))
        let item = try #require(GameContent.sampleInventoryItems.first)
        let loot = BattleLootResult(item: item, gold: 10, materials: [])
        var first = base
        var second = base
        for branch in [0, 1] {
            var candidate = branch == 0 ? first : second
            #expect(ContractsCompletion.complete(
                offerID: offer.id, hero: candidate.roster.activeHero, companion: candidate.roster.activeCompanion,
                rewards: .unsettled(.init(loot: loot, enemyEncounterLevel: 1)), save: &candidate,
                recordReceipt: { _ in },
            ) == .completed)
            let refreshed = candidate.contracts.refresh()
            #expect(refreshed)
            if branch == 0 {
                first = candidate
            } else {
                second = candidate
            }
        }
        let context = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(first, to: context.storeURL())
        let restored = try context.makeSaveStore()
        let merged = CloudSaveMerge.merge(incoming: restored.currentSave, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.gold == first.roster.gold)
        #expect(merged.roster.progressions == first.roster.progressions)
        #expect(merged.contracts.completedOfferIDs?.contains(offer.id) == true)
    }
}
