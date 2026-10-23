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

    @Test func `completed Shop does not recharge a shared purchase after its stock is pruned`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        base.inventory.items = []
        let encounter = EncounterIdentity(
            location: .journey(stageID: ShopOfferGenerator.starterShopStageID), save: base,
        )
        let stock = try ShopStockPersistence.prepare(encounter: encounter, save: &base).get()
        let offer = try #require(stock.offers.first)

        var completed = base
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &completed).get()
        let receipts = [SaveEconomicReceipt.resolved(
            from: CloudSaveSnapshot(base), to: CloudSaveSnapshot(completed), kind: .shop(encounter, .init(offer)), claim: nil,
        )]
        let completion = NonCombatEncounterCompletion.complete(
            encounter: encounter, grantingEncounterRewards: false, save: &completed,
        )
        #expect(completion == .completed)

        var peer = base
        _ = try ShopPurchaseApplier.purchase(
            offerID: offer.id, encounter: encounter, save: &peer,
        ).get()
        let mutation = CloudSaveMutation(
            id: "completed-shop", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(completed), receipts: receipts,
        )
        let head = try resolve([mutation], incoming: peer, base: base, existing: completed)
        let merged = try head.revision.snapshot.restored()
        #expect(merged.roster.gold == 100 - offer.price)
        #expect(merged.inventory.items.count(where: { $0.id == offer.item.id }) == 1)
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
        let batch = SaveEconomicMutation(base, sourceRevision: 0)
        var second = base
        _ = try batch.resolve(kind: .shop(encounter, .init(offer))) { save in
            ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &save)
        }.get()
        _ = try ShopPurchaseApplier.purchase(offerID: offer.id, encounter: encounter, save: &second).get()
        for definition in [well, field] {
            guard case .success = batch.resolve(kind: .upgrade(definition.id, 1), { save in
                HomesteadBuildMutation.apply(definition.id, targetTier: 1, at: date, to: &save)
            })
            else { Issue.record("Expected affordable build"); return }
        }
        guard case .success = HomesteadBuildMutation.apply(well.id, targetTier: 1, at: date, to: &second)
        else { Issue.record("Expected shared build"); return }
        let materials = try batch.resolve(claim: .salvage(item.id)) { save in
            ItemSalvageApplier.salvage(itemID: item.id, save: &save)
        }.get()
        let first = batch.save
        var positions: [HomesteadResource: UInt64] = [:]
        let operations = try ResolvedSaveAction.records(batch.actions, following: CloudSaveSnapshot(base), positions: &positions)
        let mutation = CloudSaveMutation(
            id: "composite", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(first), actions: operations,
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

    @Test func `duplicate operation keeps the accepted reward without granting an alternative item`() throws {
        var base = PlayerSave.testSeed
        base.inventory.items = []
        base.roster.gold = 100
        let stage = try #require(GameContent.chapters.flatMap(\.stages).first { $0.encounter.isCombat })
        let template = try #require(GameContent.sampleInventoryItems.first)
        let localItem = template.rewardInstance(for: "local-alternative")
        let acceptedItem = template.rewardInstance(for: "accepted-alternative")
        var local = base
        local.inventory.appendUniqueItem(localItem)
        local.roster.gold += 10
        local.journey.markRewardsClaimed(for: stage)
        var accepted = base
        accepted.inventory.appendUniqueItem(acceptedItem)
        accepted.roster.gold += 17
        accepted.journey.markRewardsClaimed(for: stage)
        let action = ResolvedSaveAction(
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(local), kind: .reward, claim: .journey(stage.id),
        )
        let mutation = CloudSaveMutation(
            id: "alternative", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: action.before, after: action.after, actions: [.init(action, following: action.before)],
        )
        let head = try resolve([mutation], incoming: local, base: base, existing: accepted)
        let merged = try head.revision.snapshot.restored()
        #expect(merged.roster.gold == 117)
        #expect(merged.inventory.items.map(\.id) == [acceptedItem.id])
    }

    @Test func `future operations and uncovered economic gaps refuse both attachment and replay`() throws {
        let base = PlayerSave.testSeed
        var after = base
        after.roster.gold += 5
        let action = ResolvedSaveAction(before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(after), kind: .reward, claim: nil)
        var future = ResolvedSaveAction.Record(action, following: action.before)
        future.formatVersion += 1
        let mutations = [
            CloudSaveMutation(
                id: "future-operation", changedSliceMask: PlayerSaveSlice.all.rawValue,
                before: action.before, after: action.after, actions: [future],
            ),
            CloudSaveMutation(
                id: "uncovered", changedSliceMask: PlayerSaveSlice.all.rawValue,
                before: action.before, after: action.after, actions: [],
            ),
        ]
        for mutation in mutations {
            let journal = try JSONDecoder().decode(CloudSaveJournal.self, from: JSONEncoder().encode(CloudSaveJournal([mutation])))
            for server in [Optional(base), nil] {
                #expect(throws: CloudSaveError.unsupportedSave) {
                    try resolve(Array(journal), incoming: after, base: base, existing: server)
                }
            }
        }
    }

    @Test func `structural gaps cannot replace independently replayed economics`() throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        let hero = base.roster.activeHero
        var awarded = base
        awarded.roster.gold += 5
        awarded.homestead.resources[.iron, default: 0] += 3
        awarded.roster.grantExperience(9, to: hero)
        let action = ResolvedSaveAction(
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(awarded), kind: .reward, claim: nil,
        )
        var final = awarded
        final.corruptionAltarCooldownRemaining = 1
        var peer = base
        peer.roster.gold += 17
        peer.homestead.resources[.iron, default: 0] += 7
        peer.roster.grantExperience(11, to: hero)
        let mutation = CloudSaveMutation(
            id: "award-and-structural-gap", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: action.before, after: CloudSaveSnapshot(final), actions: [.init(action, following: action.before)],
        )
        let merged = try resolve([mutation], incoming: final, base: base, existing: peer).revision.snapshot.restored()
        #expect(merged.roster.gold == 122)
        #expect(merged.homestead.resources[.iron, default: 0] == base.homestead.resources[.iron, default: 0] + 10)
        #expect(merged.roster.progression(for: hero).totalEarnedExperience == base.roster.progression(for: hero).totalEarnedExperience + 20)
        #expect(merged.corruptionAltarCooldownRemaining == 1)
    }

    @Test(arguments: [false, true])
    func `absent and empty historical receipts retain different replay semantics`(hasReceipts: Bool) throws {
        var base = PlayerSave.testSeed
        base.roster.gold = 100
        var after = base
        after.roster.gold += 5
        let mutation = CloudSaveMutation(
            id: "historical", changedSliceMask: PlayerSaveSlice.roster.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(after), receipts: hasReceipts ? [] : nil,
        )
        let decoded = try JSONDecoder().decode(CloudSaveMutation.self, from: JSONEncoder().encode(mutation))
        let merged = try resolve([decoded], incoming: after, base: base, existing: base).revision.snapshot.restored()
        #expect(merged.roster.gold == (hasReceipts ? 100 : 105))
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
