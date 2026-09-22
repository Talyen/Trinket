import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BlacksmithForgeTests {
    @Test func `forge Astral weight rises with Blacksmith tier and stacks with Moonlit Sanctum`() throws {
        #expect((0 ... 4).map(BlacksmithRecipe.astralWeightBonusPercent) == [0, 0, 10, 20, 30])
        #expect(BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: Int.min) == 0)
        #expect(BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: Int.max) == 30)
        var save = fundedSave()
        save.homestead.nodeTiers[.blacksmithForge] = 4
        save.homestead.nodeTiers[.moonlitSanctum] = 4
        save.contracts.recordVictory(encounterLevel: 40)
        let recipe = try #require(BlacksmithRecipe.matching("blacksmith-longsword"))
        var actualRandom = SeededRandomNumberGenerator(seed: 41)
        let actual = try BlacksmithForgeAttempt.prepare(recipeID: recipe.id, save: save, using: &actualRandom).get().item
        var expectedRandom = SeededRandomNumberGenerator(seed: 41)
        let expected = ItemRewardGenerator.generate(
            id: actual.id, rewardLevel: 40,
            astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent + 30,
            allowedTiers: [.basic, .astral, .unique],
            ownedTrinketIDs: [], ownedUniqueIDs: [],
            eligibleUniqueIDs: Set(GameContent.uniqueItems.filter { $0.baseType.id == recipe.baseID }.map(\.templateID)),
            fallbackBaseType: recipe.baseType, using: &expectedRandom,
        )
        #expect(actual == expected)
    }

    private func fundedSave() -> PlayerSave {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        save.inventory.items = []
        save.homestead = PlayerHomesteadState(
            resources: [.iron: 500, .wood: 500, .hide: 500],
            nodeTiers: [.blacksmithForge: 1],
        )
        return save
    }

    @Test func `catalog preserves order artwork and salvage sink`() throws {
        #expect(BlacksmithRecipe.all.map(\.baseID) == [
            "dagger", "shortsword", "longsword", "greatsword", "hatchet", "double_axe",
            "mace", "flail", "maul", "kite_shield", "plate_armor",
        ])
        #expect(Set(BlacksmithRecipe.all.map(\.id)).count == 11)
        for recipe in BlacksmithRecipe.all {
            #expect(recipe.cost.allSatisfy { $0.quantity > 0 })
            #expect(ArtCatalog.itemArtByID["\(recipe.baseID)-basic"] != nil)
            let item = try SaveTestSupport.makeGeneratedItem(baseID: recipe.baseID, rarity: .astral)
            let yields = ItemSalvage.yields(for: item)
            #expect(recipe.cost.reduce(0) { $0 + $1.quantity } > yields.reduce(0) { $0 + $1.quantity })
            for cost in recipe.cost {
                #expect(cost.quantity > (yields.first { $0.resource == cost.resource }?.quantity ?? 0))
            }
        }
    }

    @Test func `forging matches existing generation including unique ownership`() throws {
        var save = fundedSave()
        save.journey.activeStageID = nil
        save.contracts.recordVictory(encounterLevel: 40)
        save.homestead.nodeTiers[.moonlitSanctum] = 4
        for recipe in BlacksmithRecipe.all {
            var rarities: Set<Rarity> = []
            for seed in 0 ..< 100 {
                var random = SeededRandomNumberGenerator(seed: UInt64(seed))
                let attempt = try BlacksmithForgeAttempt.prepare(recipeID: recipe.id, save: save, using: &random).get()
                var comparisonRandom = SeededRandomNumberGenerator(seed: UInt64(seed))
                let expected = ItemRewardGenerator.generate(
                    id: attempt.item.id,
                    rewardLevel: CampaignRewardLevel.resolve(in: save),
                    astralChanceBonusPercent: save.homestead.effects.astralChanceBonusPercent,
                    allowedTiers: [.basic, .astral, .unique],
                    ownedTrinketIDs: [], ownedUniqueIDs: [],
                    eligibleUniqueIDs: Set(GameContent.uniqueItems.filter { $0.baseType.id == recipe.baseID }.map(\.templateID)),
                    fallbackBaseType: recipe.baseType,
                    using: &comparisonRandom,
                )
                #expect(attempt.item == expected)
                #expect(attempt.item.baseType.id == recipe.baseID)
                #expect(!attempt.item.isTrinket)
                rarities.insert(attempt.item.rarity)
            }
            #expect(rarities == [.basic, .astral, .unique])
        }
        save.inventory.items = GameContent.uniqueItems
        for seed in 0 ..< 100 {
            var random = SeededRandomNumberGenerator(seed: UInt64(seed))
            let attempt = try BlacksmithForgeAttempt.prepare(recipeID: "blacksmith-longsword", save: save, using: &random).get()
            #expect(attempt.item.rarity != .unique)
        }
    }

    @Test func `rejection and repeated application never spend twice`() throws {
        var save = fundedSave()
        var random = SeededRandomNumberGenerator(seed: 41)
        let attempt = try BlacksmithForgeAttempt.prepare(recipeID: "blacksmith-longsword", save: save, using: &random).get()
        _ = try attempt.apply(to: &save).get()
        let committed = save
        #expect(attempt.apply(to: &save) == .failure(.alreadyOwned))
        #expect(save == committed)
        save.homestead.resources = [:]
        #expect(BlacksmithForgeAttempt.prepare(recipeID: "blacksmith-dagger", save: save, using: &random).failure == .insufficientResources)
        save.homestead.nodeTiers = [:]
        #expect(BlacksmithForgeAttempt.prepare(recipeID: "blacksmith-dagger", save: save, using: &random).failure == .unavailable)
    }

    @Test(arguments: [false, true]) @MainActor func `forge commits item and costs across reload and recovery`(recovery: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performBatchMutation { $0 = fundedSave() }
        store.forcesNextDatabaseSaveFailure = recovery
        let item = try await store.forgeBlacksmithItem(recipeID: "blacksmith-longsword").get()
        #expect(store.inventory.items == [item])
        #expect(store.homestead.resources[.iron] == 468)
        #expect(store.homestead.resources[.wood] == 484)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.inventory.items == [item])
        #expect(reloaded.homestead.resources[.iron] == 468)
        #expect(reloaded.homestead.resources[.wood] == 484)
    }

    @Test @MainActor func `automatic retry spends once and reset invalidates pending craft`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performBatchMutation { $0 = fundedSave() }
        store.forcesNextSaveFailure = true
        let item = try await store.forgeBlacksmithItem(recipeID: "blacksmith-dagger").get()
        #expect(store.inventory.items == [item])
        #expect(store.homestead.resources[.iron] == 476)

        store.forcesNextSaveFailure = true
        let pending = Task { await store.forgeBlacksmithItem(recipeID: "blacksmith-dagger") }
        // Yield until the injected failure reaches the retained retry, before resetting.
        while store.forcesNextSaveFailure {
            await Task.yield()
        }
        try store.resetGameplayProgress()
        let reset = store.currentSave
        #expect(await pending.value == .failure(.invalidated))
        #expect(store.currentSave == reset)
    }

    @Test @MainActor func `failed transaction retains rolled item and rolls back cost`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performBatchMutation { $0 = fundedSave() }
        var random = SeededRandomNumberGenerator(seed: 42)
        let attempt = try BlacksmithForgeAttempt.prepare(recipeID: "blacksmith-dagger", save: store.currentSave, using: &random).get()
        let before = store.currentSave
        store.forcesNextSaveFailure = true
        let failure = store.persistTransaction(logging: "Forge failure test") { attempt.apply(to: &$0) }
        guard case .persistFailed = failure else { Issue.record("Expected failure"); return }
        #expect(store.currentSave == before)
        let success = store.persistTransaction(logging: "Forge retry test") { attempt.apply(to: &$0) }
        guard case let .committed(item) = success else { Issue.record("Expected commit"); return }
        #expect(item == attempt.item)
        #expect(store.inventory.items == [attempt.item])
    }
}

private extension Result where Failure == BlacksmithForgeFailure {
    var failure: Failure? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }
}
