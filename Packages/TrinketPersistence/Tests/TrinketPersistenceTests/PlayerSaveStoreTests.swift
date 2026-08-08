import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@MainActor
final class PlayerSaveStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func playerSavePersistsJourneyRosterInventoryAndHomestead() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        firstStore.grantGold(42)
        firstStore.grantExperience(20, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

        let secondStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(secondStore.roster.gold == 42)
        try #expect(secondStore.roster.progression(for: GameContent.heroes[0]).currentXP == 20)
        try #expect(secondStore.homestead.resources[.wood] == 14)
        try #expect(secondStore.homestead.resources[.crystal] == 2)
        _ = try #require(secondStore.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        try #expect(secondStore.journey.activeStageID == "chapter-1-stage-2")
    }

    @Test func versionedStoreAdoptsCurrentUnversionedSchema() throws {
        let storeURL = context.storeURL()
        let legacySchema = Schema(PlayerSaveSchema.models)
        do {
            let container = try ModelContainer(
                for: legacySchema,
                configurations: ModelConfiguration(
                    schema: legacySchema,
                    url: storeURL,
                    cloudKitDatabase: .none
                )
            )
            let modelContext = ModelContext(container)
            modelContext.insert(PlayerSaveRoot(save: .testSeed))
            try modelContext.save()
        }

        let versionedStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(versionedStore.roster == .testSeed)
        try #expect(versionedStore.inventory == .testSeed)
        try #expect(versionedStore.homestead == .testSeed)
        try #expect(!versionedStore.isPersistenceDegraded)
    }

    @Test func invalidStoreFallsBackWithoutDeletingSourceFiles() throws {
        let storeURL = context.storeURL()
        let originalData = Data("not-a-sqlite-store".utf8)
        try originalData.write(to: storeURL)

        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        try #expect(store.isPersistenceDegraded)
        try #expect(store.lastPersistenceError != nil)
        try #expect(Data(contentsOf: storeURL) == originalData)
    }

    @Test func swiftDataGraphStoresIndependentRecords() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        store.grantGold(5)
        store.advanceJourneyToStage("chapter-1-stage-2")
        store.grantHomestead([ResourceAmount(.wood, 3)])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        store.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))

        let container = try ModelContainer(
            for: PlayerSaveGraph.schema,
            configurations: ModelConfiguration(schema: PlayerSaveGraph.schema, url: storeURL, cloudKitDatabase: .none)
        )
        let modelContext = ModelContext(container)

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

    @Test func resetGameplayProgressRestoresFreshStart() throws {
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
        try #expect(store.currentSave.sessionGeneration == 1)
    }

    @Test func applyTestSeedMatchesDeterministicUITestBaseline() throws {
        let store = try context.makeSaveStore()
        try store.applyTestSeed()

        try #expect(store.roster == .testSeed)
        try #expect(store.inventory == .testSeed)
        try #expect(store.homestead == .testSeed)
    }

    @Test func unlockAllContentUnlocksRosterAndClearsChapterOne() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
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
        try #expect(store.labyrinth == .freshStart)
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

    @Test func equipmentLoadoutDropsMissingInventoryItemsOnLoad() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        var save = PlayerSave.testSeed
        save.roster.equipmentLoadouts["knight"] = EquipmentLoadout(
            itemIDsBySlot: [.weapon: "missing-item"]
        )
        try firstStore.performBatchMutation { $0 = save }

        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        try #expect(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)
    }

    @Test func rosterCacheReturnsConsistentHydratedState() throws {
        let store = try context.makeSaveStore()
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        let item = template.rewardInstance(for: "chapter-1-stage-1")
        store.appendInventoryItem(item)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })

        var roster = store.roster
        var loadout = roster.equipmentLoadout(for: knight)
        loadout.equip(item)
        roster.setEquipmentLoadout(loadout, for: knight)
        store.roster = roster

        let firstRead = store.roster
        let secondRead = store.roster
        try #expect(firstRead == secondRead)
        try #expect(
            firstRead.equipmentLoadout(for: knight).itemID(for: .weapon) == "chapter-1-stage-1-shortsword-basic"
        )
    }

    @Test func localMutationUpdatesModifiedAt() throws {
        let store = try context.makeSaveStore()
        let beforeLocalEdit = store.currentSave.modifiedAt
        store.grantGold(1)

        try #expect(store.currentSave.modifiedAt > beforeLocalEdit)
    }

    @Test func sanitizerDropsRemovedStages() throws {
        var journey = JourneyProgressState.initial
        journey.completedStageIDs = ["chapter-1-stage-5", "chapter-1-stage-99", "missing-stage"]
        journey.claimedRewardStageIDs = ["chapter-1-stage-5", "chapter-1-stage-99"]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        try #expect(sanitized.completedStageIDs == ["chapter-1-stage-5"])
        try #expect(sanitized.claimedRewardStageIDs == ["chapter-1-stage-5"])
    }

    @Test(arguments: [
        ("negative-xp", true),
        ("schema-version", false),
    ])
    func validateRejectsCorruptSaveFields(mode: String, expectsMessageContainsXP: Bool) throws {
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

    @Test func flushPendingPersistencePersistsDeferredMutationThroughReload() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false
        )
        store.grantGold(19)
        try #expect(store.roster.gold == 19)

        store.flushPendingPersistence()

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 19)
        try #expect(store.lastPersistenceError == nil)
    }

    @Test func localOnlyConfigurationWiresStoreURLAndRecovery() {
        let finalURL = context.storeURL()
        let resolved = PlayerSaveStoreConfiguration.resolveConfiguration(
            schema: PlayerSaveGraph.schema,
            finalURL: finalURL,
            storeName: nil,
            storeURL: nil,
            disableCloudSync: true,
            inMemoryOnly: false,
            cloudKitContainerIdentifier: PlayerSaveStore.cloudKitContainerIdentifier
        )
        #expect(resolved.recoveryURL == finalURL)
        #expect(resolved.config.url == finalURL)
    }

    @Test func performBatchMutationPreservesStateWhenValidationFails() throws {
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
    @Test func performBatchMutationRollsBackInMemoryStateWhenSaveFails() throws {
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

    @Test func resetGameplayProgressRollsBackWhenSaveFails() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
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

    @Test func deferredFlushRollsBackToLastPersistedSnapshotAcrossMutations() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false
        )
        try store.performBatchMutation({ save in
            save.roster.gold = 10
        }, persistImmediately: true)
        try #expect(store.roster.gold == 10)

        try store.performBatchMutation({ save in
            save.roster.gold = 20
        }, persistImmediately: false)
        try store.performBatchMutation({ save in
            save.roster.gold = 30
        }, persistImmediately: false)
        try #expect(store.roster.gold == 30)

        store.forcesNextSaveFailure = true
        store.flushPendingPersistence()

        try #expect(store.roster.gold == 10)
        try #expect(store.lastPersistenceError == .writeFailed)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 10)
    }

    @Test func deferredFlushPendingPersistenceRollsBackToLastPersistedSnapshot() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: false
        )
        try store.performBatchMutation({ save in
            save.roster.gold = 10
        }, persistImmediately: true)

        try store.performBatchMutation({ save in
            save.roster.gold = 30
        }, persistImmediately: false)
        try #expect(store.roster.gold == 30)

        store.forcesNextSaveFailure = true
        store.flushPendingPersistence()

        try #expect(store.roster.gold == 10)
        try #expect(store.lastPersistenceError == .writeFailed)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(reloaded.roster.gold == 10)
    }

    @Test func persistBatchReturnsFalseAndRollsBackWhenSaveFails() throws {
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
