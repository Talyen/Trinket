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
            partyBias: PartyLootBias(roster: save.roster),
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
        _ = try BlacksmithForgeApplier.apply(attempt, to: &save).get()
        let committed = save
        #expect(BlacksmithForgeApplier.apply(attempt, to: &save) == .failure(.alreadyOwned))
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
            #expect(BlacksmithForgeApplier.apply(attempt, to: &save) == .failure(expected))
            #expect(save == before)
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

        var random = SeededRandomNumberGenerator(seed: 42)
        let plan = try BlacksmithForgeApplier.prepare(recipeID: "blacksmith-dagger", save: store.currentSave, using: &random).get()
        store.forcesNextSaveFailure = true
        var attempts = 0
        var reset: PlayerSave?
        let outcome = await store.retryingSaveTransaction {
            attempts += 1
            let result = store.persistAction(logging: "Forge reset fixture") { save in
                BlacksmithForgeApplier.apply(plan, to: &save)
            }
            if case .persistFailed = result {
                try store.resetGameplayProgress()
                reset = store.currentSave
            }
            return result
        }
        #expect(attempts == 1)
        #expect(reset != nil)
        if case .some = outcome {
            Issue.record("A reset must invalidate the failed forge transaction")
        }
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
        let failure = store.persistAction(logging: "Forge failure test") { save in
            BlacksmithForgeApplier.apply(attempt, to: &save)
        }
        guard case .persistFailed = failure else { Issue.record("Expected failure"); return }
        #expect(store.currentSave == before)
        let success = store.persistAction(logging: "Forge retry test") { save in
            BlacksmithForgeApplier.apply(attempt, to: &save)
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
