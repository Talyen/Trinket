import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct ContractBoardTests {
    @Test func `board generation repair and refresh preserve the three slot rules`() {
        var board = PlayerContractsState()
        board.ensureBoard()
        let original = board
        board.ensureBoard()
        #expect(board == original)
        #expect(board.offers.map(\.difficulty) == ContractDifficulty.allCases)
        #expect(Set(board.offers.map(\.enemyID)).count == 3)
        for offer in board.offers {
            #expect(GameContent.enemy(matching: offer.enemyID)?.isBoss == offer.difficulty.isBoss)
        }
        board.refresh()
        for offer in board.offers {
            #expect(offer.id != original.offer(for: offer.difficulty)?.id)
            #expect(offer.enemyID != original.offer(for: offer.difficulty)?.enemyID)
        }

        let retained = board.offers.filter { $0.difficulty != .easy }
        board = PlayerContractsState(offers: retained + [
            ContractOffer(id: "invalid", difficulty: .easy, enemyID: "missing-enemy"),
        ])
        board.ensureBoard()
        #expect(board.offers.count == 3)
        #expect(board.offers.filter { $0.difficulty != .easy } == retained)
        #expect(Set(board.offers.map(\.enemyID)).count == 3)
    }

    @Test(arguments: ContractDifficulty.allCases)
    func `claim grants regular rewards once and replaces only its slot`(difficulty: ContractDifficulty) throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard()
        let offer = try #require(save.contracts.offer(for: difficulty))
        let before = save
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        let level = EncounterLevelResolver.contractEnemyLevel(
            difficulty: difficulty, partyAverageLevel: save.roster.activePartyAverageLevel,
        )
        let loot = ContractsCompletion.resolveLoot(for: offer, encounterLevel: level, save: save)
        var expected = before
        VictoryRewardApplier.grantVictoryRewards(
            hero: hero, companion: companion, encounterLevel: level, stageGold: loot.gold,
            battleEarnedGold: 5, materialRewards: loot.materials, item: loot.item, save: &expected,
        )

        #expect(ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion, encounterLevel: level,
            loot: loot, battleEarnedGold: 5, save: &save,
        ))
        #expect(save.roster == expected.roster)
        #expect(save.inventory == expected.inventory)
        #expect(save.homestead.resources == expected.homestead.resources)
        #expect(save.homestead.nodeTiers == before.homestead.nodeTiers)
        #expect(save.journey == before.journey)
        #expect(save.spires == before.spires)
        #expect(save.labyrinth == before.labyrinth)
        #expect(save.contracts.offers.count == 3)
        #expect(save.contracts.offer(for: difficulty)?.id != offer.id)
        #expect(save.contracts.offer(for: difficulty)?.enemyID != offer.enemyID)
        #expect(save.contracts.offers.filter { $0.difficulty != difficulty }
            == before.contracts.offers.filter { $0.difficulty != difficulty })

        let claimed = save
        #expect(!ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion, encounterLevel: level,
            loot: loot, battleEarnedGold: 5, save: &save,
        ))
        #expect(save == claimed)
    }

    @Test(arguments: [ItemDropTier.unique, .trinket])
    func `catalog reward identities remain claimable`(tier: ItemDropTier) throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard()
        let hard = try #require(save.contracts.offer(for: .hard))
        let candidates = tier == .unique ? GameContent.uniqueItems : GameContent.trinketItems
        let item = try #require(candidates.first)
        let loot = BattleLootResult(item: item, gold: 10, materials: [])
        #expect(ContractsCompletion.complete(
            offerID: hard.id, hero: save.roster.activeHero, companion: save.roster.activeCompanion,
            encounterLevel: 5, loot: loot, save: &save,
        ))
        #expect(save.inventory.item(matching: item.id) == item)
    }
}

@MainActor
final class ContractsPersistenceTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `legacy missing board opens lazily and generated offers survive reload`() throws {
        var legacy = PlayerSave.testSeed
        legacy.schemaVersion = 16
        try SaveTestSupport.writeRoot(legacy, to: context.storeURL()) { modelContext in
            let roots = try modelContext.fetch(FetchDescriptor<PlayerSaveRoot>())
            let root = try #require(roots.first)
            root.contractsPayload = nil
        }
        let store = try context.makeSaveStore()
        #expect(!store.recoveredAfterStoreDeletion)
        #expect(store.contracts == .freshStart)
        #expect(store.roster == legacy.roster)
        #expect(store.inventory == legacy.inventory)
        #expect(store.persistBatch(logging: "Contracts test") { $0.contracts.ensureBoard() })
        let first = store.contracts
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.contracts == first)
        #expect(reloaded.persistBatch(logging: "Contracts test") { $0.contracts.refresh() })
        #expect(reloaded.contracts != first)
        let refreshed = try context.makeReloadedStore()
        #expect(refreshed.contracts == reloaded.contracts)
    }

    #if DEBUG
    @Test func `failed claim rolls back all slices and retries exactly once across reload`() throws {
        let store = try context.makeSaveStore()
        #expect(store.persistBatch(logging: "Contracts test") { save in
            save.roster = .testSeed
            save.contracts.ensureBoard()
        })
        let offer = try #require(store.contracts.offer(for: .standard))
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let level = store.roster.activePartyAverageLevel
        let loot = ContractsCompletion.resolveLoot(for: offer, encounterLevel: level, save: store.currentSave)
        let before = store.currentSave
        store.forcesNextSaveFailure = true
        let failed = store.persistBatch(logging: "Contracts test") { save in
            ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        }
        #expect(!failed)
        #expect(store.currentSave == before)
        let failedReload = try context.makeReloadedStore()
        #expect(failedReload.currentSave == before)
        #expect(failedReload.persistBatch(logging: "Contracts test") { save in
            ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        })
        let claimed = failedReload.currentSave
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.currentSave == claimed)
        var applied = true
        #expect(reloaded.persistBatch(logging: "Contracts test") { save in
            applied = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        })
        #expect(!applied)
        #expect(reloaded.currentSave == claimed)
    }
    #endif
}
