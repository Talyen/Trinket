import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct HomesteadPercentageRewardTests {
    @Test @MainActor func `small reward fractions survive disk reload and pay exactly once`() throws {
        let context = try PersistenceTestContext()
        let date = Date(timeIntervalSince1970: 2000000000)
        let store = try context.makeSaveStore()
        #expect(store.persistBatch(logging: "Seed percentage rewards") { save in
            save.roster.gold = 0
            save.homestead = .init(
                resources: [:], nodeTiers: [.wishingWell: 4, .moonlitSanctum: 4], lastProductionAt: date,
            )
        })
        for _ in 0 ..< 4 {
            #expect(store.persistBatch(logging: "Small battle reward") { save in
                VictoryRewardApplier.grantVictoryRewards(
                    party: (save.roster.activeHero, save.roster.activeCompanion),
                    encounterLevel: 1, stageGold: 1, grantsCombatExperience: false,
                    materialRewards: [.init(.gems, 1)], item: nil, save: &save,
                    recordReceipt: { _ in },
                )
            })
        }
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 4)
        #expect(reloaded.homestead.resources[.gems] == 4)
        #expect(reloaded.homestead.rewardRemainders == .init(gold: 80, gems: 80))
        #expect(reloaded.persistBatch(logging: "Pay fractional reward") { save in
            VictoryRewardApplier.grantVictoryRewards(
                party: (save.roster.activeHero, save.roster.activeCompanion),
                encounterLevel: 1, stageGold: 1, grantsCombatExperience: false,
                materialRewards: [.init(.gems, 1)], item: nil, save: &save,
                recordReceipt: { _ in },
            )
        })
        let final = try context.makeReloadedStore()
        #expect(final.roster.gold == 6)
        #expect(final.homestead.resources[.gems] == 6)
        #expect(final.homestead.rewardRemainders == nil)
    }

    @Test func `old Homestead payload decodes with its tiers and no reward fractions`() throws {
        let state = PlayerHomesteadState(resources: [.gems: 3], nodeTiers: [.library: 4], lastProductionAt: .distantPast)
        let data = try JSONEncoder().encode(state)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "rewardRemainders")
        let decoded = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded == state)
        #expect(decoded.effects.experienceBonusPercent == 20)
    }

    @Test(arguments: [0, 80])
    func `independent cloud rewards reconcile both unpaid and already paid fractions`(starting: Int) {
        var base = PlayerSave.testSeed
        base.roster.gold = 10
        base.homestead.resources[.gems] = 10
        base.homestead.rewardRemainders = .init(gold: starting, gems: starting)
        var left = base
        var right = base
        for branch in 0 ..< 2 {
            var save = branch == 0 ? left : right
            var fractions = save.homestead.rewardRemainders ?? .zero
            save.roster.gold += 1 + fractions.bonus(for: .gold, amount: 1, percent: 20)
            save.homestead.resources[.gems, default: 0] += 1 + fractions.bonus(for: .gems, amount: 1, percent: 20)
            save.homestead.rewardRemainders = fractions
            if branch == 0 {
                left = save
            } else {
                right = save
            }
        }
        let merged = CloudSaveMerge.merge(incoming: left, existing: right, base: base, preferIncoming: true)
        #expect(merged.roster.gold == (starting == 0 ? 12 : 13))
        #expect(merged.homestead.resources[.gems] == (starting == 0 ? 12 : 13))
        #expect(merged.homestead.rewardRemainders == .init(gold: starting == 0 ? 40 : 20, gems: starting == 0 ? 40 : 20))
    }

    @Test func `stale Mystery fractions reject a payout until its existing item is refreshed`() throws {
        var save = PlayerSave.testSeed
        save.roster.gold = 0
        save.homestead.rewardRemainders = .init(gold: 95)
        let item = try #require(GameContent.sampleInventoryItems.first).rewardInstance(for: "fraction-offer")
        let basis = HomesteadMysteryReward(resource: .gold, amount: 10, percent: 5)
        var previewFractions = save.homestead.rewardRemainders ?? .zero
        let offer = MysteryOffer(
            choiceID: "gold",
            item: item,
            bonus: basis.resolve(remainders: &previewFractions),
            homesteadReward: basis,
        )
        #expect(save.homestead.rewardRemainders?.gold == 95)
        save.homestead.rewardRemainders = nil
        let before = save
        #expect(MysteryEffectApplier.apply(offer, save: &save).isEmpty)
        #expect(save == before)
        var refreshedFractions = save.homestead.rewardRemainders ?? .zero
        let refreshed = MysteryOffer(
            choiceID: offer.choiceID,
            item: offer.item,
            bonus: basis.resolve(remainders: &refreshedFractions),
            homesteadReward: basis,
        )
        let result = MysteryEffectApplier.apply(refreshed, save: &save)
        #expect(result.grantedGold == 10)
        #expect(result.grantedItems == [item])
        #expect(save.homestead.rewardRemainders?.gold == 50)
    }

    @Test func `Mystery preview does not spend fractions and direct claims do`() {
        var save = PlayerSave.testSeed
        save.roster.gold = 0
        save.homestead.nodeTiers[.wishingWell] = 4
        var random = SeededRandomNumberGenerator(seed: 7)
        for _ in 0 ..< 5 {
            _ = MysteryEffectApplier.apply(
                [.gainGold(1)], stageID: "fraction-test", choiceID: "gold", encounterLevel: 1,
                rewardLevel: 1, save: &save, using: &random,
            )
        }
        #expect(save.roster.gold == 6)
        #expect(save.homestead.rewardRemainders == nil)
    }
}
