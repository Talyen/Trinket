import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct BattleLootTests {
    @Test @MainActor func `opening boss Trinket is claimed once and remains claimed after reload`() throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-10"))
        let before = store.currentSave
        let expected = BattleLootContext(save: before).journey(for: stage).item
        #expect(expected.isTrinket)
        #expect(store.completeJourneyStages([stage], hero: store.roster.activeHero, companion: store.roster.activeCompanion))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.journey.claimedRewardStageIDs.contains(stage.id))
        #expect(reloaded.inventory.items.contains { $0.templateID == expected.templateID })
        let claimed = reloaded.currentSave
        #expect(reloaded.completeJourneyStages([stage], hero: reloaded.roster.activeHero, companion: reloaded.roster.activeCompanion))
        #expect(reloaded.currentSave == claimed)
        #expect(BattleLootContext(save: claimed).journey(for: stage) == BattleLoot.resolve(
            .journey(stage: stage), encounterLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: GameContent.chapters),
            enemyIsBoss: true, worldSeed: claimed.worldSeed, ownership: RewardOwnership(claimed),
            astralChanceBonusPercent: claimed.homestead.effects.astralChanceBonusPercent,
        ))
    }

    @Test func `noncombat offer quality follows won encounters across modes`() {
        let node = LabyrinthNode(id: "deep", type: .mystery, depth: 17, clusterID: "cluster")
        var save = SaveTestSupport.makeSave()
        save.labyrinth.nodes[node.id] = node
        for stageID in ["chapter-4-stage-4", "chapter-4-stage-8"] {
            let encounter = EncounterIdentity(location: .journey(stageID: stageID), save: save)
            #expect(encounter.rewardLevel(in: save) == 1)
        }
        let encounter = EncounterIdentity(location: .labyrinth(nodeID: node.id), save: save)
        #expect(encounter.rewardLevel(in: save) == 1)
        save.contracts.recordVictory(encounterLevel: 25)
        #expect(encounter.rewardLevel(in: save) == 25)
    }

    @Test func `a won Contract uses its own encounter level for item quality`() throws {
        var save = SaveTestSupport.makeSave()
        save.contracts.ensureBoard(eligibleModifiers: [.gold])
        let offer = try #require(save.contracts.offer(for: .standard))
        #expect(CampaignRewardLevel.resolve(in: save) == 1)
        let actual = BattleLootContext(save: save).contract(for: offer, encounterLevel: 20)
        let expected = BattleLoot.resolve(
            .contract(offerID: offer.id), encounterLevel: 20, enemyIsBoss: false,
            worldSeed: save.worldSeed, ownership: RewardOwnership(save),
        )
        #expect(actual == expected)
    }

    @Test func `authored astral rewards remain the requested template`() throws {
        let template = try #require(GameContent.itemTemplate(matching: "longsword-astral"))
        let stage = Stage(
            id: "authored-loot", chapterID: "chapter-1", chapterNumber: 1, stageNumber: 1,
            encounter: .mysteryEvent(eventID: ""),
            rewards: StageReward(gold: 0, itemTemplateIDs: [template.templateID]),
        )
        for seed in UInt64(1) ... 8 {
            var save = SaveTestSupport.makeSave(worldSeed: seed)
            let before = save.inventory.items.count
            StageCompletion.claimRewardsIfNeeded(
                for: stage, hero: save.roster.activeHero, companion: save.roster.activeCompanion, save: &save,
                recordReceipt: { _ in },
            )
            #expect(save.inventory.items.count == before + 1)
            #expect(save.inventory.items.last?.templateID == template.templateID)
            #expect(save.inventory.items.last?.isTrinket == false)
        }
    }

    @Test func `duplicate headline item converts to consolation gold`() throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })
        var save = SaveTestSupport.makeSave()
        let trinket = try #require(GameContent.trinketItems.first)
        save.inventory.appendUniqueItem(trinket)
        let goldBefore = save.roster.gold

        let settlement = VictoryRewardApplier.settleVictoryRewards(
            party: (hero, companion),
            encounterLevel: 10,
            stageGold: 0,
            materialRewards: [],
            item: trinket,
            save: save,
        )
        VictoryRewardApplier.apply(
            settlement, hero: hero, companion: companion,
            save: &save, recordReceipt: { _ in },
        )

        let range = BattleLoot.quantityRange(forLevel: 10)
        #expect(save.roster.gold - goldBefore == (range.lowerBound + range.upperBound) / 2)
        #expect(save.inventory.items.count(where: { $0.templateID == trinket.templateID }) == 1)
    }
}
