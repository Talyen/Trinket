import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PlayerSaveStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `player save persists journey roster inventory and homestead`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        firstStore.grantGold(42)
        firstStore.grantExperience(5, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

        let secondStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(secondStore.roster.gold == 42)
        try #expect(secondStore.roster.progression(for: GameContent.heroes[0]).currentXP == 5)
        try #expect(secondStore.homestead.resources[.wood] == 14)
        try #expect(secondStore.homestead.resources[.crystal] == 2)
        _ = try #require(secondStore.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(secondStore.journey.activeStageID == "chapter-1-stage-2")
        try #expect(secondStore.worldSeed == firstStore.worldSeed)
        try #expect(secondStore.worldSeed != 0)
    }

    @Test func `material balances above legacy cap survive reload`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        var homestead = firstStore.homestead
        homestead.resources[.wood] = 12345
        firstStore.homestead = homestead

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(reloaded.homestead.resources[.wood] == 12345)
    }

    @Test func `versioned store adopts current unversioned schema`() throws {
        let storeURL = context.storeURL()
        let legacySchema = Schema(PlayerSaveSchema.models)
        try SaveTestSupport.writeRoot(.testSeed, to: storeURL, schema: legacySchema)

        let versionedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(versionedStore.roster == .testSeed)
        try #expect(versionedStore.inventory == .testSeed)
        try #expect(versionedStore.homestead == .testSeed)
        try #expect(!versionedStore.isPersistenceDegraded)
    }

    @Test func `corrupt store recovers by deleting and recreating`() throws {
        let storeURL = context.storeURL()
        let originalData = Data("not-a-sqlite-store".utf8)
        try originalData.write(to: storeURL)

        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)

        try #expect(!store.isPersistenceDegraded)
        try #expect(store.recoveredAfterStoreDeletion)
        if case let .storeUnavailable(message) = store.lastPersistenceError {
            #expect(message.contains("fresh start"))
        } else {
            Issue.record("Expected store-unavailable error after wipe recovery")
        }

        store.grantGold(42)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 42)
        #expect(!reloaded.isPersistenceDegraded && !reloaded.recoveredAfterStoreDeletion)
        #expect(reloaded.lastPersistenceError == nil)
    }

    @Test func `mutate roster persists through hub`() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        let persisted = firstStore.mutateRoster {
            $0.gold = 17
        }
        try #expect(persisted)
        try #expect(firstStore.roster.gold == 17)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 17)
    }

    @Test func `untouched labyrinth survives gold only mutation`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        var labyrinth = PlayerLabyrinthState.freshStart
        labyrinth.ensureMap(seed: 42)
        store.labyrinth = labyrinth
        let labyrinthBefore = store.labyrinth
        try #require(labyrinthBefore.hasMap)

        store.grantGold(7)

        try #expect(store.labyrinth == labyrinthBefore)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.labyrinth == labyrinthBefore)
    }

    @Test func `swift data graph stores independent records`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        store.grantGold(5)
        store.advanceJourneyToStage("chapter-1-stage-2")
        store.grantHomestead([ResourceAmount(.wood, 3)])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        store.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))

        let modelContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)

        try #expect(try modelContext.fetch(FetchDescriptor<RosterModel>()).first?.gold == 5)
        try #expect(try modelContext.fetch(FetchDescriptor<JourneyStageProgressModel>()).contains {
            $0.stageID == "chapter-1-stage-1" && $0.isCompleted
        })
        try #expect(try modelContext.fetch(FetchDescriptor<InventoryItemModel>()).contains {
            $0.id == "chapter-1-stage-1-shortsword-basic"
        })
        try #expect(try modelContext.fetch(FetchDescriptor<HomesteadResourceBalanceModel>()).contains {
            $0.resourceID == HomesteadResource.wood.rawValue && $0.quantity == 3
        })
    }

    @Test func `reset gameplay progress restores fresh start`() throws {
        let store = try context.makeSaveStore()
        store.grantGold(99)
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        store.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        store.advanceJourneyToStage("chapter-1-stage-2")

        try store.resetGameplayProgress()

        try #expect(store.roster == .freshStart)
        try #expect(store.inventory == .freshStart)
        try #expect(store.homestead == .freshStart)
        try #expect(store.journey == .initial)
        try #expect(store.starterSelection == .fresh)
        try #expect(store.currentSave.sessionGeneration == 1)
    }

    @Test func `unlock all content unlocks roster and clears chapter one`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        try store.unlockAllContent()

        let chapter1 = try #require(GameContent.chapters.first { $0.id == "chapter-1" })
        let chapter1StageIDs = Set(chapter1.stages.map(\.id))
        try #expect(store.roster.unlockedHeroIDs == Set(GameContent.heroes.map(\.id)))
        try #expect(store.roster.unlockedCompanionIDs == Set(GameContent.companions.map(\.id)))
        try #expect(store.roster.highestHeroLevel == 20)
        try #expect(store.roster.highestCompanionLevel == 20)
        try #expect(store.roster.gold == 900)
        try #expect(store.journey.completedStageIDs == chapter1StageIDs)
        try #expect(store.journey.activeChapterID == "chapter-2")
        try #expect(store.journey.activeStageID == "chapter-2-stage-1")
        try #expect(store.spires == .freshStart)
        try #expect(!store.labyrinth.hasMap)
        try #expect(store.labyrinth.worldSeed == store.worldSeed)
        try #expect(store.inventory == .testSeed)
        for resource in HomesteadResource.allCases where resource != .gold {
            try #expect(store.homestead.resources[resource] == 900)
        }
        for nodeID in HomesteadNodeID.allCases {
            let maxTier = HomesteadNodeCatalog.maxTierByNodeID[nodeID, default: 3]
            try #expect(store.homestead.tier(for: nodeID) == maxTier - 1)
        }
        try #expect(store.currentSave.sessionGeneration == 1)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.highestHeroLevel == 20)
        try #expect(reloaded.roster.gold == 900)
        try #expect(reloaded.journey.activeChapterID == "chapter-2")
        try #expect(reloaded.journey.activeStageID == "chapter-2-stage-1")
        try #expect(reloaded.spires == .freshStart)
        for resource in HomesteadResource.allCases where resource != .gold {
            try #expect(reloaded.homestead.resources[resource] == 900)
        }
        try #expect(reloaded.homestead.pendingProduction[.food] == 10)
        try #expect(reloaded.homestead.pendingProduction[.herbs] == 10)
        try #expect(reloaded.homestead.pendingProduction[.crystal] == 10)
        try #expect(reloaded.homestead.pendingProduction[.hide] == 10)
        try #expect(reloaded.homestead.pendingProduction[.gold] == 10)
    }

    @Test func `noop batch mutation does not bump modified at`() throws {
        let store = try context.makeSaveStore()
        let before = store.currentSave.modifiedAt

        try store.performBatchMutation { _ in }

        try #expect(store.currentSave.modifiedAt == before)
    }

    @Test(arguments: [
        ("negative-xp", true),
        ("schema-version", false),
    ])
    func `validate rejects corrupt save fields`(mode: String, expectsMessageContainsXP: Bool) throws {
        var save = PlayerSave.fresh
        switch mode {
        case "negative-xp":
            save.roster.progressions["knight"] = CombatantProgression(level: 1, currentXP: -1, requiredXP: 100)
        case "schema-version":
            save.schemaVersion = 0
        default:
            Issue.record("Unexpected validate mode \(mode)")
            return
        }

        let error = try #require(throws: PlayerSavePersistenceError.self) {
            try PlayerSaveSanitizer.validate(save)
        }
        guard case let .invalidSave(message) = error else {
            Issue.record("Expected invalidSave, got \(error)")
            return
        }
        if expectsMessageContainsXP {
            try #expect(message.contains("current XP"))
        }
    }

    @Test func `flush pending persistence persists deferred mutation through reload`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false,
        )
        store.grantGold(19)
        try #expect(store.roster.gold == 19)

        store.flushPendingPersistence()

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 19)
        try #expect(store.lastPersistenceError == nil)
    }

    @Test func `perform batch mutation preserves state when validation fails`() throws {
        let store = try context.makeSaveStore()
        store.grantGold(25)
        let snapshot = store.currentSave

        try #expect(throws: (any Error).self) {
            try store.performBatchMutation { save in
                save.schemaVersion = 0
            }
        }

        try #expect(store.currentSave == snapshot)
        try #expect(store.roster.gold == 25)
        try #expect(store.lastPersistenceError == nil)
    }

    #if DEBUG
    @Test func `perform batch mutation rolls back in memory state when save fails`() throws {
        let store = try context.makeSaveStore()
        store.grantGold(10)
        store.forcesNextSaveFailure = true

        let error = try #require(throws: PlayerSavePersistenceError.self) {
            try store.performBatchMutation { save in
                save.roster.gold += 50
            }
        }
        guard case .writeFailed = error else {
            Issue.record("Expected writeFailed, got \(error)")
            return
        }

        try #expect(store.roster.gold == 10)
        try #expect(store.lastPersistenceError == .writeFailed)
    }

    @Test func `ensure required graph rolls back when save fails`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        store.grantGold(10)
        let snapshot = store.currentSave
        store.dropInventoryGraphForTesting()
        store.forcesNextSaveFailure = true

        store.reapplyRequiredGraphForTesting()

        try #expect(store.currentSave == snapshot)
        try #expect(store.lastPersistenceError == .writeFailed)
        try #expect(!store.isPersistenceDegraded)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 10)
        try #expect(!reloaded.isPersistenceDegraded)
    }

    @Test func `reset gameplay progress rolls back when save fails`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true,
        )
        store.grantGold(10)
        let snapshot = store.currentSave
        store.forcesNextSaveFailure = true

        let error = try #require(throws: PlayerSavePersistenceError.self) {
            try store.resetGameplayProgress()
        }
        guard case .writeFailed = error else {
            Issue.record("Expected writeFailed, got \(error)")
            return
        }

        try #expect(store.currentSave == snapshot)
        try #expect(store.lastPersistenceError == .writeFailed)

        store.flushPendingPersistence()
        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.currentSave == snapshot)
    }

    @Test(arguments: [[20, 30], [30]])
    func `deferred flush rolls back to last persisted snapshot`(deferredGold: [Int]) throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false,
        )
        try store.performBatchMutation({ save in
            save.roster.gold = 10
        }, persistImmediately: true)
        try #expect(store.roster.gold == 10)

        for gold in deferredGold {
            try store.performBatchMutation({ save in
                save.roster.gold = gold
            }, persistImmediately: false)
        }
        try #expect(store.roster.gold == deferredGold.last)

        store.forcesNextSaveFailure = true
        store.flushPendingPersistence()

        try #expect(store.roster.gold == 10)
        try #expect(store.lastPersistenceError == .writeFailed)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 10)
    }

    @Test func `persist batch returns false and rolls back when save fails`() throws {
        let store = try context.makeSaveStore()
        store.grantGold(10)
        store.forcesNextSaveFailure = true

        let persisted = store.persistBatch(logging: "Test persist") { save in
            save.roster.gold += 50
        }

        #expect(!persisted)
        try #expect(store.roster.gold == 10)
        try #expect(store.lastPersistenceError == .writeFailed)
    }
    #endif
}

#if DEBUG
extension PlayerSaveStoreTests {
    @Test func `immediate persist retires deferred rollback so A later flush failure keeps saved progress`() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false,
        )
        try store.performBatchMutation({ save in
            save.roster.gold = 10
        }, persistImmediately: true)
        try store.performBatchMutation({ save in
            save.roster.gold = 20
        }, persistImmediately: false)
        try store.performBatchMutation({ save in
            save.roster.gold = 50
        }, persistImmediately: true)
        try #expect(store.roster.gold == 50)

        store.forcesNextSaveFailure = true
        store.flushPendingPersistence()

        try #expect(store.roster.gold == 50)
        try #expect(store.lastPersistenceError == nil)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 50)
    }
}
#endif

private extension PlayerSaveStore {
    func grantExperience(_ amount: Int, to combatant: Combatant) {
        var updated = roster
        updated.grantExperience(amount, to: combatant)
        roster = updated
    }

    func grantGold(_ amount: Int) {
        var updated = roster
        updated.grantGold(amount)
        roster = updated
    }

    func appendInventoryItem(_ item: InventoryItem) {
        var updated = inventory
        updated.items.append(item)
        inventory = updated
    }

    func advanceJourneyToStage(_ stageID: String) {
        var updated = journey
        updated.completedStageIDs.insert("chapter-1-stage-1")
        updated.activeStageID = stageID
        journey = updated
    }

    func grantHomestead(_ rewards: [ResourceAmount]) {
        var updated = homestead
        updated.grant(rewards)
        homestead = updated
    }
}

@Model
final class LegacyPrimaryStatsRow {
    var combatantID: String = ""
    var wisdom: Int = 0

    init(combatantID: String = "", wisdom: Int = 0) {
        self.combatantID = combatantID
        self.wisdom = wisdom
    }
}

@MainActor
struct PlayerSaveSchemaMigrationTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func `store migrates when current schema removes an entity`() throws {
        let storeURL = context.storeURL()
        let legacySchema = Schema(PlayerSaveSchema.models + [LegacyPrimaryStatsRow.self])
        try SaveTestSupport.writeRoot(.testSeed, to: storeURL, schema: legacySchema) { context in
            context.insert(LegacyPrimaryStatsRow(combatantID: "knight", wisdom: 7))
        }

        let migratedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(!migratedStore.isPersistenceDegraded)
        try #expect(migratedStore.roster == .testSeed)
        try #expect(migratedStore.inventory == .testSeed)
        try #expect(migratedStore.journey == .testSeed)
    }
}
