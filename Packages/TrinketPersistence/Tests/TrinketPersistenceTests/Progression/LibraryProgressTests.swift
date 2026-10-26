import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct LibraryProgressTests {
    @Test(arguments: [false, true]) @MainActor
    func `first encounter survives reload without a victory and stale encounters cannot cross reset`(recovery: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let claim = store.prepareBattleRewardClaim(
            at: nil,
            heroID: store.roster.activeHeroID,
            companionID: store.roster.activeCompanionID,
            enemyID: "slime",
        )
        store.forcesNextDatabaseSaveFailure = recovery
        store.recordBattleEncounter(claim)
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.library.progress.encounteredEnemyIDs == ["slime"])
        #expect(reloaded.library.progress.defeatedEnemyIDs.isEmpty)
        try store.resetGameplayProgress()
        store.recordBattleEncounter(claim)
        #expect(store.library.progress.encounteredEnemyIDs.isEmpty)
        #expect(try context.makeReloadedStore().library.progress.encounteredEnemyIDs.isEmpty)
    }

    @Test @MainActor func `victory unlock and focused craft commit once with their triggering writes`() async throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performFixtureMutation { save in
            save.homestead = PlayerHomesteadState(
                resources: [.wood: 500, .iron: 500, .herbs: 500],
                nodeTiers: [.library: 1, .archeryRange: 1],
            )
            save.library.defeat("slime")
            save.library.defeat("goblin")
        }
        let claim = store.prepareBattleRewardClaim(
            at: nil,
            heroID: store.roster.activeHeroID,
            companionID: store.roster.activeCompanionID,
            enemyID: "the_blight_treant",
        )
        let plan = BattleRewardPlan(stageGold: 0, goldFindPercent: 0, heroExperience: 0, companionExperience: 0, materials: [], items: [])
        let award = plan.settle(battleGold: .init(), inputs: RewardSettlementInputs(
            save: store.currentSave,
            hero: store.roster.activeHero,
            companion: store.roster.activeCompanion,
        ))
        store.forcesNextSaveFailure = true
        guard case .persistFailed = store.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("Refused victory must remain retryable")
            return
        }
        #expect(!store.library.progress.unlockedRecipeIDs.contains("archery-shortbow-poison"))
        guard case .committed = store.completeBattle(claim, award: award, enemyEncounterLevel: nil) else {
            Issue.record("Retry must commit the same victory")
            return
        }
        #expect(claim.completedResearchIDs == ["forest-field-notes"])
        #expect(try context.makeReloadedStore().library.progress.unlockedRecipeIDs.contains("archery-shortbow-poison"))
        let before = store.homestead.resources
        let item = try await store.craftEquipmentItem(recipeID: "archery-shortbow-poison").get()
        #expect(item.baseType.id == "shortbow" && item.affixes.contains { $0.keywords.contains(.poison) })
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.inventory.items.contains { $0.id == item.id })
        #expect(reloaded.homestead.resources[.wood] == before[.wood, default: 0] - 48)
        #expect(reloaded.homestead.resources[.iron] == before[.iron, default: 0] - 24)
        #expect(reloaded.homestead.resources[.herbs] == before[.herbs, default: 0] - 8)
    }

    @Test @MainActor func `distributed graph and wire snapshots migrate without losing progress`() throws {
        let context = try PersistenceTestContext()
        try autoreleasepool {
            let schema = Schema(versionedSchema: PlayerSaveSchemaV3.self)
            let container = try SaveTestSupport.makeContainer(storeURL: context.storeURL(), schema: schema)
            let old = PlayerSaveSchemaV3.PlayerSaveRoot()
            old.worldSeed = PlayerSave.testWorldSeed
            let roster = PlayerSaveSchemaV3.RosterModel()
            roster.gold = 42
            old.roster = roster
            roster.root = old
            let journey = PlayerSaveSchemaV3.JourneyProgressModel()
            let stage = PlayerSaveSchemaV3.JourneyStageProgressModel(stageID: "chapter-1-stage-1", isCompleted: true)
            stage.journey = journey
            journey.stages = [stage]
            old.journey = journey
            journey.root = old
            let modelContext = ModelContext(container)
            modelContext.insert(old)
            try modelContext.save()
        }
        let migrated = try context.makeReloadedStore()
        #expect(migrated.currentSave.schemaVersion == PlayerSave.currentSchemaVersion)
        #expect(migrated.roster.gold == 42)
        #expect(migrated.library.progress.defeatedEnemyIDs.contains("slime"))
        #expect(try context.makeReloadedStore().library == migrated.library)

        var snapshot = PlayerSaveSnapshot(migrated.currentSave)
        snapshot.schemaVersion = 18
        snapshot.library = nil
        let decoded = try snapshot.decodedSave()
        #expect(decoded.schemaVersion == PlayerSave.currentSchemaVersion)
        let repaired = PlayerSaveSanitizer.sanitize(decoded)
        #expect(repaired.library.progress.defeatedEnemyIDs.contains("slime"))
        snapshot.schemaVersion = PlayerSave.currentSchemaVersion + 1
        #expect(throws: PlayerSavePersistenceError.self) { try snapshot.decodedSave() }
    }

    @Test func `same epoch union retains discoveries and unknown payload bytes roundtrip`() throws {
        var left = PlayerSave.testSeed
        var right = left
        left.library.encounter("slime")
        right.library.encounter("goblin")
        let merged = CloudSaveMerge.merge(incoming: left, existing: right, base: nil, preferIncoming: true)
        #expect(merged.library.progress.encounteredEnemyIDs.isSuperset(of: ["slime", "goblin"]))
        let opaque = Data("{\"version\":99,\"future\":\"retain\"}".utf8)
        left.library = PlayerLibraryState(payload: opaque)
        let snapshot = try JSONDecoder().decode(PlayerSaveSnapshot.self, from: JSONEncoder().encode(PlayerSaveSnapshot(left)))
        #expect(try snapshot.decodedSave().library.encodedPayload() == opaque)
    }

    @Test(arguments: [false, true]) @MainActor
    func `newer opaque Library history survives cloud merge and reload`(newerIsIncoming: Bool) throws {
        let olderPayload = Data("{\"version\":99,\"future\":\"older\"}".utf8)
        let newerPayload = Data("{\"version\":99,\"future\":\"newer\"}".utf8)
        var older = PlayerSave.testSeed
        older.modifiedAt = Date(timeIntervalSince1970: 100)
        older.library = PlayerLibraryState(payload: olderPayload)
        var newer = older
        newer.modifiedAt = Date(timeIntervalSince1970: 200)
        newer.library = PlayerLibraryState(payload: newerPayload)

        let merged = CloudSaveMerge.merge(
            incoming: newerIsIncoming ? newer : older,
            existing: newerIsIncoming ? older : newer,
            base: nil,
            preferIncoming: !newerIsIncoming,
        )
        #expect(try merged.library.encodedPayload() == newerPayload)
        let snapshot = try JSONDecoder().decode(PlayerSaveSnapshot.self, from: JSONEncoder().encode(PlayerSaveSnapshot(merged)))
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(snapshot.decodedSave())
        #expect(try reloaded.library.encodedPayload() == newerPayload)

        var readable = PlayerLibraryState()
        readable.merge(newer.library)
        #expect(try readable.encodedPayload() == newerPayload)
        readable.merge(PlayerLibraryState())
        #expect(try readable.encodedPayload() == newerPayload)
    }
}
