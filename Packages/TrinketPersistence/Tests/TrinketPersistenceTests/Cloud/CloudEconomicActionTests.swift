import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudEconomicActionTests {
    @Test func `economic replay preserves fractional rewards and spending after another branch pays the carry`() throws {
        var base = PlayerSave.fresh
        base.roster.gold = 100
        base.homestead.resources[.gems] = 10
        base.homestead.rewardRemainders = HomesteadRewardRemainders(gold: 90, gems: 90)
        var after = base
        after.roster.gold += 1
        after.homestead.resources[.gems, default: 0] += 1
        after.homestead.rewardRemainders = HomesteadRewardRemainders(gold: 10, gems: 20)
        after.roster.grantExperience(5, to: base.roster.activeHero)
        let action = try #require(CloudEconomicAction.record(from: base, to: after))
        var existing = base
        existing.roster.gold = 130
        existing.homestead.resources[.gems] = 17
        existing.homestead.rewardRemainders = HomesteadRewardRemainders(gold: 10, gems: 20)
        existing.roster.grantExperience(9, to: base.roster.activeHero)
        var merged = CloudSaveMerge.merge(incoming: after, existing: existing, base: base, preferIncoming: true)
        try action.replay(onto: &merged, existing: existing, before: base)
        #expect(merged.roster.gold == 130)
        #expect(merged.homestead.resources[.gems] == 17)
        #expect(merged.homestead.rewardRemainders == HomesteadRewardRemainders(gold: 30, gems: 50))
        #expect(merged.roster.progression(for: base.roster.activeHero).totalEarnedExperience == 14)

        var spent = base
        spent.roster.gold -= 7
        spent.homestead.resources[.gems, default: 0] -= 3
        let spending = try #require(CloudEconomicAction.record(from: base, to: spent))
        let previous = merged
        try spending.replay(onto: &merged, existing: previous, before: base)
        #expect(merged.roster.gold == 123)
        #expect(merged.homestead.resources[.gems] == 14)
        #expect(merged.homestead.rewardRemainders == previous.homestead.rewardRemainders)
    }

    @Test func `legacy compacted records stay conservative while subsequent economic actions survive`() throws {
        var base = PlayerSave.fresh
        base.roster.gold = 100
        base.contracts.ensureBoard()
        let offer = try #require(base.contracts.offer(for: .easy))
        var compacted = base
        compacted.contracts.completedOfferIDs = [offer.id]
        compacted.roster.gold = 130
        var existing = base
        existing.contracts.completedOfferIDs = [offer.id]
        existing.roster.gold = 140
        let legacy = CloudSaveMutation(
            id: "legacy", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(compacted),
        )
        // Encode exactly the old shape: there was no optional economy member.
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "economy")
        let decoded = try JSONDecoder().decode(CloudSaveMutation.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.economy == nil)
        var after = compacted
        after.roster.gold += 3
        let next = CloudSaveMutation(
            id: "next", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(compacted), after: CloudSaveSnapshot(after),
            economy: CloudEconomicAction.record(from: compacted, to: after),
        )
        let result = try resolve([decoded, next, next], incoming: after, base: base, existing: existing)
        #expect(result.revision.snapshot.roster.gold == 143)
    }

    @Test(arguments: [false, true])
    func `a future economic version rejects the entire upload instead of acknowledging lost effects`(explicitReceipt: Bool) throws {
        let base = PlayerSave.fresh
        var after = base
        after.roster.gold = 5
        var action = try #require(CloudEconomicAction.record(from: base, to: after))
        var receipt = SaveEconomicReceipt(kind: .reward, effects: action)
        if explicitReceipt {
            receipt.formatVersion += 1
        } else {
            action.formatVersion += 1
        }
        let mutation = CloudSaveMutation(
            id: "future", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(after),
            economy: explicitReceipt ? nil : action, receipts: explicitReceipt ? [receipt] : nil,
        )
        for serverSave in [Optional(base), nil] {
            #expect(throws: CloudSaveError.unsupportedSave) {
                try resolve([mutation], incoming: after, base: base, existing: serverSave)
            }
        }
    }

    @Test @MainActor func `purchase salvage and upgrades in one batch retain exact costs and retirement through replay`() throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.inventory.items = []
        base.homestead = PlayerHomesteadState(resources: [.wood: 100, .herbs: 100, .gems: 100], nodeTiers: [:], lastProductionAt: date)
        let item = try #require(GameContent.sampleInventoryItems.first { ItemSalvage.isEligible($0) }).rewardInstance(for: "receipt-shop")
        let offer = ShopOffer(id: "receipt-offer", item: item, price: 20)
        let encounter = EncounterIdentity(location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base)
        let payload = try ShopStockPersistence.encode(ShopStock(offers: [offer]), encounter: encounter)
        ShopStockPersistence.setPayload(payload, encounter: encounter, save: &base)
        let well = try #require(GameContent.homesteadNode(matching: .wishingWell))
        let field = try #require(GameContent.homesteadNode(matching: .wheatField))
        var first = base
        var second = base
        var receipts: [SaveEconomicReceipt] = []
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &first, recordReceipt: { receipts.append($0) })
            .get()
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &second, recordReceipt: { _ in }).get()
        for definition in [well, field] {
            guard case .success = HomesteadBuildMutation.apply(
                definition,
                targetTier: 1,
                at: date,
                to: &first,
                recordReceipt: { receipts.append($0) },
            )
            else { Issue.record("Expected affordable build"); return }
        }
        guard case .success = HomesteadBuildMutation.apply(well, targetTier: 1, at: date, to: &second, recordReceipt: { _ in })
        else { Issue.record("Expected shared build"); return }
        let materials = try ItemSalvageApplier.salvage(itemID: item.id, save: &first, recordReceipt: { receipts.append($0) }).get()
        let mutation = CloudSaveMutation(
            id: "composite", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(first), receipts: receipts,
        )
        let head = try resolve([mutation], incoming: first, base: base, existing: second)
        let merged = try head.revision.snapshot.restored()
        #expect(merged.roster.gold == 75)
        #expect(merged.inventory.item(matching: item.id) == nil)
        for resource in HomesteadResource.allCases where resource != .gold {
            let spent = [well, field].flatMap { $0.tier(1)?.cost ?? [] }.filter { $0.resource == resource }.reduce(0) { $0 + $1.quantity }
            let earned = materials.filter { $0.resource == resource }.reduce(0) { $0 + $1.quantity }
            #expect(merged.homestead.resources[resource, default: 0] == base.homestead.resources[resource, default: 0] - spent + earned)
        }
        let retry = CloudSaveRequest(
            id: "retry", action: .upload, baseEpoch: "epoch", baseRevisionID: "base", authoritySequence: 0,
            revision: CloudSaveRevision(id: "retry", clock: ["incoming": 2], snapshot: CloudSaveSnapshot(first)),
            baseSnapshot: CloudSaveSnapshot(base), mutations: CloudSaveJournal([mutation]),
        )
        let repeated = try CloudSaveReconciler.resolve(retry, against: CloudServerSave(head: head, changeToken: Data(), serverTime: date))
            .head
        #expect(repeated.revision.snapshot.roster.gold == head.revision.snapshot.roster.gold)
        #expect(repeated.revision.snapshot.homestead.resources == head.revision.snapshot.homestead.resources)
        let fixture = try PersistenceTestContext()
        let reloaded = try fixture.seedAndReload(merged)
        #expect(reloaded.roster.gold == 75)
        #expect(reloaded.inventory.item(matching: item.id) == nil)
        #expect(reloaded.homestead.tier(for: .wheatField) == 1)
        #expect(reloaded.homestead.tier(for: .wishingWell) == 1)
    }

    private func resolve(
        _ mutations: [CloudSaveMutation], incoming: PlayerSave, base: PlayerSave, existing: PlayerSave?,
    ) throws -> CloudSaveHead {
        let request = CloudSaveRequest(
            id: "upload", action: .upload, baseEpoch: existing == nil ? nil : "epoch", baseRevisionID: "base", authoritySequence: 0,
            revision: CloudSaveRevision(id: "upload", clock: ["incoming": 1], snapshot: CloudSaveSnapshot(incoming)),
            baseSnapshot: CloudSaveSnapshot(base), mutations: CloudSaveJournal(mutations),
        )
        let server = existing.map { save in
            CloudServerSave(
                head: CloudSaveHead(
                    epoch: "epoch", resetCount: 0, authoritySequence: 0,
                    revision: CloudSaveRevision(id: "remote", clock: ["remote": 1], snapshot: CloudSaveSnapshot(save)),
                ),
                changeToken: Data(), serverTime: base.homestead.lastProductionAt,
            )
        }
        return try CloudSaveReconciler.resolve(request, against: server).head
    }
}
