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
        let unavailableRefresh = board.refresh()
        #expect(!unavailableRefresh)
        board.earnRefresh()
        let refreshed = board.refresh()
        #expect(refreshed)
        #expect(!board.refreshAvailable)
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

    @Test func `item quality follows won encounters rather than roster leveling`() throws {
        var save = SaveTestSupport.makeSave()
        let early = ContractsCompletion.campaignRewardLevel(in: save)
        save.roster.progressions[save.roster.activeHeroID] = .at(level: 40)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 40)
        #expect(ContractsCompletion.campaignRewardLevel(in: save) == early)

        let lastStage = try #require(GameContent.chapters.last?.stages.last)
        save.journey.complete(lastStage, in: GameContent.chapters)
        let late = ContractsCompletion.campaignRewardLevel(in: save)
        #expect(late > early)
        #expect(late == min(40, StageCompletion.resolvedEncounterLevel(for: lastStage, in: GameContent.chapters)))
        save.journey.activeStageID = nil
        #expect(ContractsCompletion.campaignRewardLevel(in: save) == late)
        save.contracts.recordVictory(encounterLevel: 60)
        #expect(ContractsCompletion.campaignRewardLevel(in: save) == 40)
    }

    @Test func `damaged Contract offers do not erase the earned loot milestone`() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "offers": "unreadable", "highestWonEncounterLevel": 27, "refreshAvailable": true,
        ])
        let restored = PlayerContractsState.decodePayload(payload)
        #expect(restored.offers.isEmpty)
        #expect(restored.highestWonEncounterLevel == 27)
        #expect(restored.refreshAvailable)
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
            battleGold: .init(gained: 5),
            experienceEarnedPercent: ContractsCompletion.effectiveModifier(for: offer, inventory: before.inventory).experienceBonusPercent,
            materialRewards: loot.materials, item: loot.item, save: &expected,
        )

        #expect(ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion, encounterLevel: level,
            loot: loot, battleGold: .init(gained: 5), save: &save,
        ) == .completed)
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
        #expect(ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion, encounterLevel: level,
            loot: loot, battleGold: .init(gained: 5), save: &save,
        ) == .alreadyCompleted)
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
        ) == .completed)
        #expect(save.inventory.item(matching: item.id) == item)
    }
}

struct ContractsPersistenceTests {
    @Test @MainActor func `missing board opens lazily and generated offers survive reload`() throws {
        let context = try PersistenceTestContext()
        let saved = PlayerSave.testSeed
        try SaveTestSupport.writeRoot(saved, to: context.storeURL()) { modelContext in
            let roots = try modelContext.fetch(FetchDescriptor<PlayerSaveRoot>())
            let root = try #require(roots.first)
            root.contractsPayload = nil
        }
        let store = try context.makeSaveStore()
        #expect(!store.isPersistenceDegraded)
        #expect(store.contracts == .freshStart)
        #expect(store.roster == saved.roster)
        #expect(store.inventory == saved.inventory)
        #expect(store.persistBatch(logging: "Contracts test") { $0.contracts.ensureBoard(eligibleModifiers: [.keyword(.deathsDoor)]) })
        let first = store.contracts
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.contracts == first)
        #expect(reloaded.persistBatch(logging: "Contracts test") {
            $0.contracts.earnRefresh()
            _ = $0.contracts.refresh()
        })
        #expect(reloaded.contracts != first)
        let refreshed = try context.makeReloadedStore()
        #expect(refreshed.contracts == reloaded.contracts)
    }

    @Test @MainActor func `legacy contract payload survives reload without replacing offers`() throws {
        let context = try PersistenceTestContext()
        var saved = PlayerSave.testSeed
        saved.contracts.ensureBoard()
        let legacyOffers = saved.contracts.offers.map { offer in
            ["id": offer.id, "difficulty": offer.difficulty.rawValue, "enemyID": offer.enemyID]
        }
        let payload = try JSONSerialization.data(withJSONObject: ["offers": legacyOffers])
        try SaveTestSupport.writeRoot(saved, to: context.storeURL()) { modelContext in
            let root = try #require(modelContext.fetch(FetchDescriptor<PlayerSaveRoot>()).first)
            root.contractsPayload = payload
        }
        let store = try context.makeSaveStore()
        #expect(store.contracts.offers.map(\.id) == saved.contracts.offers.map(\.id))
        #expect(store.contracts.offers.allSatisfy { $0.rewardModifier == .gold })
        #expect(store.persistBatch(logging: "Legacy contracts") { $0.contracts.ensureBoard() })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.contracts == store.contracts)
    }

    #if DEBUG
    @Test @MainActor func `failed claim rolls back all slices and retries exactly once across reload`() throws {
        let context = try PersistenceTestContext()
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
            _ = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        }
        #expect(!failed)
        #expect(store.currentSave == before)
        let failedReload = try context.makeReloadedStore()
        #expect(failedReload.currentSave == before)
        #expect(failedReload.persistBatch(logging: "Contracts test") { save in
            _ = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        })
        let claimed = failedReload.currentSave
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.currentSave == claimed)
        var applied = EncounterCompletion.completed
        #expect(reloaded.persistBatch(logging: "Contracts test") { save in
            applied = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, encounterLevel: level, loot: loot, save: &save,
            )
        })
        #expect(applied == .alreadyCompleted)
        #expect(reloaded.currentSave == claimed)
    }
    #endif
}
