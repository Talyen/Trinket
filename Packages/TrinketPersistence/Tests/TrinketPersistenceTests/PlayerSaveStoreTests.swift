import SwiftData
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

@Suite @MainActor
final class PlayerSaveStoreTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func playerSavePersistsJourneyRosterInventoryAndHomestead() throws {
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        firstStore.grantGold(42)
        firstStore.grantExperience(20, to: GameContent.heroes[0])
        firstStore.grantHomestead([ResourceAmount(.wood, 14), ResourceAmount(.crystal, 2)])
        let template = try #require(GameContent.itemTemplate(matching: "shortsword-basic"))
        firstStore.appendInventoryItem(template.rewardInstance(for: "chapter-1-stage-1"))
        firstStore.advanceJourneyToStage("chapter-1-stage-2")

        let secondStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)

        #expect(secondStore.roster.gold == 42)
        #expect(secondStore.roster.progression(for: GameContent.heroes[0]).currentXP == 20)
        #expect(secondStore.homestead.resources[.wood] == 14)
        #expect(secondStore.homestead.resources[.crystal] == 2)
        _ = try #require(secondStore.inventory.item(matching: "chapter-1-stage-1-shortsword-basic"))
        #expect(secondStore.journey.activeStageID == "chapter-1-stage-2")
    }

    @Test func swiftDataGraphStoresIndependentRecords() throws {
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
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

        #expect(try modelContext.fetch(FetchDescriptor<RosterModel>()).first?.gold == 5)
        #expect(try modelContext.fetch(FetchDescriptor<JourneyStageProgressModel>()).contains {
            $0.stageID == "chapter-1-stage-1" && $0.isCompleted
        })
        #expect(try modelContext.fetch(FetchDescriptor<InventoryItemModel>()).contains {
            $0.id == "chapter-1-stage-1-shortsword-basic"
        })
        #expect(try modelContext.fetch(FetchDescriptor<HomesteadResourceBalanceModel>()).contains {
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

        #expect(store.roster == .freshStart)
        #expect(store.inventory == .freshStart)
        #expect(store.homestead == .freshStart)
        #expect(store.journey == .initial)
        #expect(store.currentSave.sessionGeneration == 1)
    }

    @Test func applyTestSeedMatchesDeterministicUITestBaseline() throws {
        let store = try context.makeSaveStore()
        try store.applyTestSeed()

        #expect(store.roster == .testSeed)
        #expect(store.inventory == .testSeed)
        #expect(store.homestead == .testSeed)
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

        #expect(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)
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
        #expect(firstRead == secondRead)
        #expect(
            firstRead.equipmentLoadout(for: knight).itemID(for: .weapon) == "chapter-1-stage-1-shortsword-basic"
        )
    }

    @Test func localMutationUpdatesModifiedAt() throws {
        let store = try context.makeSaveStore()
        let beforeLocalEdit = store.currentSave.modifiedAt
        store.grantGold(1)

        #expect(store.currentSave.modifiedAt > beforeLocalEdit)
    }

    @Test func sanitizerUsesCatalogOrderForLastCompletedStage() {
        var journey = JourneyProgressState.initial
        journey.completedStageIDs = ["chapter-1-stage-9", "chapter-1-stage-10"]
        journey.lastCompletedStageID = "chapter-1-stage-9"

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        #expect(sanitized.lastCompletedStageID == "chapter-1-stage-10")
    }

    @Test func validateRejectsNegativeProgressionXP() throws {
        var save = PlayerSave.fresh
        save.roster.progressions["knight"] = CombatantProgression(level: 1, currentXP: -1, requiredXP: 100)

        let error = try #require(throws: PlayerSavePersistenceError.self) {
            try PlayerSaveSanitizer.validate(save)
        }
        guard case let .invalidSave(message) = error else {
            Issue.record("Expected invalidSave, got \(error)")
            return
        }
        #expect(message.contains("current XP"))
    }

    @Test func validateRejectsInvalidSchemaVersion() throws {
        var save = PlayerSave.fresh
        save.schemaVersion = 0

        let error = try #require(throws: PlayerSavePersistenceError.self) {
            try PlayerSaveSanitizer.validate(save)
        }
        guard case .invalidSave = error else {
            Issue.record("Expected invalidSave, got \(error)")
            return
        }
    }

    @Test func performBatchMutationPreservesStateWhenValidationFails() throws {
        let store = try context.makeSaveStore()
        store.grantGold(25)
        let snapshot = store.currentSave

        #expect(throws: (any Error).self) {
            try store.performBatchMutation { save in
                save.schemaVersion = 0
            }
        }

        #expect(store.currentSave == snapshot)
        #expect(store.roster.gold == 25)
        #expect(store.lastPersistenceError == nil)
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

        #expect(store.roster.gold == 10)
        #expect(store.lastPersistenceError == .writeFailed)
    }
    #endif
    @Test func inMemoryStoreIsNotMarkedDegraded() throws {
        let store = try PlayerSaveStore(inMemoryOnly: true)
        #expect(store.isPersistenceDegraded == false)
        #expect(store.lastPersistenceError == nil)
    }

    @Test func storeUnavailableErrorIsEquatable() {
        #expect(PlayerSavePersistenceError.storeUnavailable("a") == .storeUnavailable("a"))
        #expect(PlayerSavePersistenceError.storeUnavailable("a") != .storeUnavailable("b"))
    }
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
        updated.lastCompletedStageID = "chapter-1-stage-1"
        journey = updated
    }

    func grantHomestead(_ rewards: [ResourceAmount]) {
        var updated = homestead
        updated.grant(rewards)
        homestead = updated
    }
}
