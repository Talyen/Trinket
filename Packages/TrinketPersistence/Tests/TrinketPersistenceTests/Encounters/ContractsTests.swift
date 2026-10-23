import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct ContractBoardTests {
    @Test func `refresh requires and consumes the earned permission`() {
        var board = PlayerContractsState()
        board.ensureBoard()
        let original = board
        let unavailableRefresh = board.refresh()
        #expect(!unavailableRefresh)
        #expect(board == original)
        board.earnRefresh()
        let refreshed = board.refresh()
        #expect(refreshed)
        #expect(!board.refreshAvailable)
        #expect(board.offers != original.offers)
    }

    @Test func `item quality follows won encounters rather than roster leveling`() throws {
        var save = SaveTestSupport.makeSave()
        let early = CampaignRewardLevel.resolve(in: save)
        save.roster.progressions[save.roster.activeHeroID] = .at(level: 40)
        save.roster.progressions[save.roster.activeCompanionID] = .at(level: 40)
        #expect(CampaignRewardLevel.resolve(in: save) == early)

        let lastStage = try #require(GameContent.chapters.last?.stages.last)
        save.journey.complete(lastStage, in: GameContent.chapters)
        let late = CampaignRewardLevel.resolve(in: save)
        #expect(late > early)
        #expect(late == min(40, EncounterLevelResolver.journeyEnemyLevel(for: lastStage, in: GameContent.chapters)))
        save.journey.activeStageID = nil
        #expect(CampaignRewardLevel.resolve(in: save) == late)
        save.contracts.recordVictory(encounterLevel: 60)
        #expect(CampaignRewardLevel.resolve(in: save) == 40)
    }

    @Test func `damaged Contract offers do not erase the earned loot milestone`() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "offers": "unreadable", "highestWonEncounterLevel": 27, "refreshAvailable": true,
            "completedOfferIDs": ["claimed-contract"],
        ])
        let restored = PlayerContractsState.decodePayload(payload)
        #expect(restored.offers.isEmpty)
        #expect(restored.highestWonEncounterLevel == 27)
        #expect(restored.refreshAvailable)
        #expect(restored.completedOfferIDs == ["claimed-contract"])

        // A damaged scalar must not discard readable pinned offers or receipts.
        var board = PlayerContractsState()
        board.ensureBoard()
        let encoded = try JSONEncoder().encode(board)
        var fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        fields["highestWonEncounterLevel"] = "unreadable"
        fields["completedOfferIDs"] = ["claimed-contract"]
        let recovered = try PlayerContractsState.decodePayload(JSONSerialization.data(withJSONObject: fields))
        #expect(recovered.offers == board.offers)
        #expect(recovered.completedOfferIDs == ["claimed-contract"])
    }

    @Test(arguments: ContractDifficulty.allCases)
    func `claim grants regular rewards once and replaces only its slot`(difficulty: ContractDifficulty) throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard()
        let offer = try #require(save.contracts.offer(for: difficulty))
        let before = save
        let hero = save.roster.activeHero
        let companion = save.roster.activeCompanion
        let level = EncounterScaling.contract(difficulty)
            .resolve(partyAverageLevel: save.roster.activePartyAverageLevel).level
        let loot = BattleLootContext(save: save).contract(for: offer, encounterLevel: level)
        var expected = before
        let settlement = VictoryRewardApplier.settleVictoryRewards(
            party: (hero, companion), encounterLevel: level, stageGold: loot.gold,
            battleGold: .init(gained: 5),
            experienceEarnedPercent: RewardOwnership(before.inventory).resolved(offer.rewardModifier).experienceBonusPercent,
            materialRewards: loot.materials, item: loot.item, save: expected,
        )
        VictoryRewardApplier.apply(
            settlement, hero: hero, companion: companion,
            save: &expected,
        )

        #expect(ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion,
            rewards: .unsettled(.init(
                battleGold: .init(gained: 5), loot: loot, enemyEncounterLevel: level,
            )), save: &save,
        ) == .completed)
        #expect(save.roster == expected.roster)
        #expect(save.inventory == expected.inventory)
        #expect(save.homestead.resources == expected.homestead.resources)
        #expect(save.homestead.nodeTiers == before.homestead.nodeTiers)
        #expect(save.journey == before.journey)
        #expect(save.spires == before.spires)
        #expect(save.labyrinth == before.labyrinth)
        #expect(save.contracts.highestWonEncounterLevel == level)
        #expect(save.contracts.offers.count == 3)
        #expect(save.contracts.offer(for: difficulty)?.id != offer.id)
        #expect(save.contracts.offer(for: difficulty)?.enemyID != offer.enemyID)
        #expect(save.contracts.offers.filter { $0.difficulty != difficulty }
            == before.contracts.offers.filter { $0.difficulty != difficulty })

        let claimed = save
        #expect(ContractsCompletion.complete(
            offerID: offer.id, hero: hero, companion: companion,
            rewards: .unsettled(.init(
                battleGold: .init(gained: 5), loot: loot, enemyEncounterLevel: level,
            )), save: &save,
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
            rewards: .unsettled(.init(loot: loot, enemyEncounterLevel: 5)), save: &save,
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
        #expect(store
            .persistFixtureBatch(logging: "Contracts test") { $0.contracts.ensureBoard(eligibleModifiers: [.keyword(.deathsDoor)]) })
        let first = store.contracts
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.contracts == first)
        #expect(reloaded.persistFixtureBatch(logging: "Contracts test") {
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
        #expect(store.persistFixtureBatch(logging: "Legacy contracts") { $0.contracts.ensureBoard() })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.contracts == store.contracts)
    }

    #if DEBUG
    @Test @MainActor func `failed claim rolls back all slices and retries exactly once across reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        #expect(store.persistFixtureBatch(logging: "Contracts test") { save in
            save.roster = .testSeed
            save.contracts.ensureBoard()
        })
        let offer = try #require(store.contracts.offer(for: .standard))
        let hero = store.roster.activeHero
        let companion = store.roster.activeCompanion
        let level = store.roster.activePartyAverageLevel
        let loot = BattleLootContext(save: store.currentSave).contract(for: offer, encounterLevel: level)
        let before = store.currentSave
        store.forcesNextSaveFailure = true
        let failed = store.persistFixtureBatch(logging: "Contracts test") { save in
            _ = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, rewards: .unsettled(.init(loot: loot, enemyEncounterLevel: level)),
                save: &save,
            )
        }
        #expect(!failed)
        #expect(store.currentSave == before)
        let failedReload = try context.makeReloadedStore()
        #expect(failedReload.currentSave == before)
        #expect(failedReload.persistFixtureBatch(logging: "Contracts test") { save in
            _ = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, rewards: .unsettled(.init(loot: loot, enemyEncounterLevel: level)),
                save: &save,
            )
        })
        let claimed = failedReload.currentSave
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.currentSave == claimed)
        var applied = EncounterCompletion.completed
        #expect(reloaded.persistFixtureBatch(logging: "Contracts test") { save in
            applied = ContractsCompletion.complete(
                offerID: offer.id, hero: hero, companion: companion, rewards: .unsettled(.init(loot: loot, enemyEncounterLevel: level)),
                save: &save,
            )
        })
        #expect(applied == .alreadyCompleted)
        #expect(reloaded.currentSave == claimed)
    }
    #endif
}
