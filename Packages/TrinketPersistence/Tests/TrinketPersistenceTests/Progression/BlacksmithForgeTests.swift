import Foundation
import Testing
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketContent
@testable import TrinketPersistence

struct BlacksmithForgeTests {
    @Test func `forge Astral weight comes only from Blacksmith tier`() throws {
        #expect((0 ... 4).map(BlacksmithRecipe.astralWeightBonusPercent) == [0, 0, 10, 20, 30])
        #expect(BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: Int.min) == 0)
        #expect(BlacksmithRecipe.astralWeightBonusPercent(blacksmithTier: Int.max) == 30)
        var save = fundedSave()
        save.homestead.nodeTiers[.blacksmithForge] = 4
        save.homestead.nodeTiers[.moonlitSanctum] = 4
        save.contracts.recordVictory(encounterLevel: 40)
        let recipe = try #require(BlacksmithRecipe.matching("blacksmith-longsword"))
        var actualRandom = SeededRandomNumberGenerator(seed: 41)
        let actual = try BlacksmithForgeApplier.prepare(recipeID: recipe.id, save: save, using: &actualRandom).get().item
        save.homestead.nodeTiers[.moonlitSanctum] = nil
        var withoutSanctumRandom = SeededRandomNumberGenerator(seed: 41)
        let withoutSanctum = try BlacksmithForgeApplier.prepare(recipeID: recipe.id, save: save, using: &withoutSanctumRandom).get().item
        #expect(actual.rarity == withoutSanctum.rarity)
        #expect(actual.affixes == withoutSanctum.affixes)
        var expectedRandom = SeededRandomNumberGenerator(seed: 41)
        let expected = ItemRewardGenerator.generate(
            id: actual.id, rewardLevel: 40,
            astralChanceBonusPercent: 30,
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

    @Test func `rejection and repeated application never spend twice`() throws {
        var save = fundedSave()
        var random = SeededRandomNumberGenerator(seed: 41)
        let attempt = try BlacksmithForgeApplier.prepare(recipeID: "blacksmith-longsword", save: save, using: &random).get()
        _ = try BlacksmithForgeApplier.apply(attempt, to: &save, recordReceipt: { _ in }).get()
        let committed = save
        #expect(BlacksmithForgeApplier.apply(attempt, to: &save, recordReceipt: { _ in }) == .failure(.alreadyOwned))
        #expect(save == committed)
        save.homestead.resources = [:]
        #expect(BlacksmithForgeApplier.prepare(recipeID: "blacksmith-dagger", save: save, using: &random).failure == .insufficientResources)
        save.homestead.nodeTiers = [:]
        #expect(BlacksmithForgeApplier.prepare(recipeID: "blacksmith-dagger", save: save, using: &random).failure == .unavailable)
    }

    @Test func `prepared forge rechecks availability and each material before spending`() throws {
        let initial = fundedSave()
        var random = SeededRandomNumberGenerator(seed: 41)
        let attempt = try BlacksmithForgeApplier.prepare(recipeID: "blacksmith-longsword", save: initial, using: &random).get()
        let blockedResources: [HomesteadResource?] = [nil, .iron, .wood]
        for resource in blockedResources {
            var save = initial
            let expected: BlacksmithForgeFailure
            if let resource {
                let cost = try #require(attempt.recipe.cost.first { $0.resource == resource })
                save.homestead.resources[resource] = cost.quantity - 1
                expected = .insufficientResources
            } else {
                save.homestead.nodeTiers = [:]
                expected = .unavailable
            }
            let before = save
            var receipts: [SaveEconomicReceipt] = []
            #expect(BlacksmithForgeApplier.apply(attempt, to: &save, recordReceipt: { receipts.append($0) }) == .failure(expected))
            #expect(save == before)
            #expect(receipts.isEmpty)
        }
    }

    @Test(arguments: [false, true]) @MainActor func `forge commits item and costs across reload and recovery`(recovery: Bool) async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performFixtureMutation { $0 = fundedSave() }
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
        try store.performFixtureMutation { $0 = fundedSave() }
        store.forcesNextSaveFailure = true
        let item = try await store.forgeBlacksmithItem(recipeID: "blacksmith-dagger").get()
        #expect(store.inventory.items == [item])
        #expect(store.homestead.resources[.iron] == 476)

        store.forcesNextSaveFailure = true
        let pending = Task { await store.forgeBlacksmithItem(recipeID: "blacksmith-dagger") }
        defer { pending.cancel() }
        // Yield until the injected failure reaches the retained retry, before resetting.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while store.forcesNextSaveFailure, clock.now < deadline {
            await Task.yield()
        }
        try #require(!store.forcesNextSaveFailure, "Forge did not reach the retained save retry")
        try store.resetGameplayProgress()
        let reset = store.currentSave
        #expect(await pending.value == .failure(.invalidated))
        #expect(store.currentSave == reset)
    }

    @Test @MainActor func `failed transaction retains rolled item and rolls back cost`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performFixtureMutation { $0 = fundedSave() }
        var random = SeededRandomNumberGenerator(seed: 42)
        let attempt = try BlacksmithForgeApplier.prepare(recipeID: "blacksmith-dagger", save: store.currentSave, using: &random).get()
        let before = store.currentSave
        store.forcesNextSaveFailure = true
        let failure = store.persistTransaction(logging: "Forge failure test") { save, recordReceipt in
            BlacksmithForgeApplier.apply(attempt, to: &save, recordReceipt: recordReceipt)
        }
        guard case .persistFailed = failure else { Issue.record("Expected failure"); return }
        #expect(store.currentSave == before)
        let success = store.persistTransaction(logging: "Forge retry test") { save, recordReceipt in
            BlacksmithForgeApplier.apply(attempt, to: &save, recordReceipt: recordReceipt)
        }
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
