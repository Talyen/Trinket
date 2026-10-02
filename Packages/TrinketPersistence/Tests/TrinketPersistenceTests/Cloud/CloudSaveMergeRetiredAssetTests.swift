import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaveMergeRetiredAssetTests {
    @Test(arguments: [false, true]) @MainActor
    func `completed Contract cannot return from a newer unrelated board`(reverseBranches: Bool) throws {
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let offer = ContractOffer(id: "retired-contract", difficulty: .easy, enemyID: enemy.id)
        var stale = PlayerSave.testSeed
        stale.contracts = PlayerContractsState(offers: [offer])
        stale.modifiedAt = Date(timeIntervalSince1970: 200)
        var completed = stale
        completed.modifiedAt = Date(timeIntervalSince1970: 100)
        let replaced = completed.contracts.replace(offerID: offer.id) { difficulty, _, _ in
            ContractOffer(id: "replacement-contract", difficulty: difficulty, enemyID: enemy.id)
        }
        #expect(replaced)

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? completed : stale,
            existing: reverseBranches ? stale : completed,
            base: nil, preferIncoming: true,
        )
        let context = try PersistenceTestContext()
        let restoredSnapshot = try CloudSaveSnapshot(merged).restored()
        let reloaded = try context.seedAndReload(restoredSnapshot)
        var restored = reloaded.currentSave
        #expect(restored.contracts.completedOfferIDs?.contains(offer.id) == true)
        #expect(!restored.contracts.offers.contains { $0.id == offer.id })
        let before = restored
        let outcome = try ContractsCompletion.complete(
            offerID: offer.id, hero: restored.roster.activeHero, companion: restored.roster.activeCompanion,
            encounterLevel: 1,
            loot: BattleLootResult(item: #require(GameContent.sampleInventoryItems.first), gold: 10, materials: []),
            save: &restored,
        )
        #expect(outcome == .alreadyCompleted)
        #expect(restored == before)
    }

    @Test func `completed Contract receipt rejects a stale offer before sanitization`() throws {
        let enemy = try #require(GameContent.enemies.first { !$0.isBoss })
        let offer = ContractOffer(id: "already-won-contract", difficulty: .easy, enemyID: enemy.id)
        var save = PlayerSave.testSeed
        save.contracts = PlayerContractsState(offers: [offer])
        save.contracts.completedOfferIDs = [offer.id]
        let before = save
        let outcome = try ContractsCompletion.complete(
            offerID: offer.id, hero: save.roster.activeHero, companion: save.roster.activeCompanion,
            encounterLevel: 1,
            loot: BattleLootResult(item: #require(GameContent.sampleInventoryItems.first), gold: 10, materials: []),
            save: &save,
        )
        #expect(outcome == .alreadyCompleted)
        #expect(save == before)
        #expect(save.contracts.sanitized().offers.isEmpty)
    }

    @Test(arguments: [false, true], [false, true]) @MainActor
    func `salvage retires shared gear even when another device corrupts it`(
        reverseBranches: Bool, corruptionIsNewer: Bool,
    ) throws {
        let baseType = try #require(GameContent.itemBaseType(matching: "longsword"))
        var random = SeededRandomNumberGenerator(seed: 42)
        let item = ItemGenerator().generate(
            id: "retired-cloud-sword", baseType: baseType, rarity: .basic,
            fixedAffixCount: 2, using: &random,
        )
        var base = PlayerSave.testSeed
        base.inventory.items = [item]
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [:], lastProductionAt: Date(timeIntervalSince1970: 2000000000),
        )
        var corrupted = base
        let corruption = try #require(ItemCorruption.corrupt(item, using: &random))
        corrupted.inventory.items = [corruption.item]
        corrupted.modifiedAt = Date(timeIntervalSince1970: corruptionIsNewer ? 200 : 100)
        var salvaged = base
        salvaged.modifiedAt = Date(timeIntervalSince1970: corruptionIsNewer ? 100 : 200)
        let outcome = ItemSalvageApplier.salvage(itemID: item.id, save: &salvaged)
        guard case let .success(yields) = outcome else {
            Issue.record("The shared sword must be salvageable")
            return
        }

        let merged = CloudSaveMerge.merge(
            incoming: reverseBranches ? salvaged : corrupted,
            existing: reverseBranches ? corrupted : salvaged,
            base: base, preferIncoming: true,
        )
        let context = try PersistenceTestContext()
        let restoredSnapshot = try CloudSaveSnapshot(merged).restored()
        let reloaded = try context.seedAndReload(restoredSnapshot)
        #expect(reloaded.inventory.item(matching: item.id) == nil)
        for yield in yields {
            #expect(reloaded.homestead.resources[yield.resource, default: 0] == yield.quantity)
        }
    }
}
