import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct TrinketPersistenceOptimizationTests {
    @Test func `sanitize journey prunes completed shop payloads`() {
        var journey = JourneyProgressState.initial
        let completedStage = "chapter-1-stage-1"
        let activeStage = "chapter-1-stage-2"
        journey.completedStageIDs = [completedStage]
        journey.activeStageID = activeStage
        journey.shopPayloads = [
            completedStage: Data([0x01, 0x02]),
            activeStage: Data([0x03, 0x04]),
        ]

        let sanitized = PlayerSaveSanitizer.sanitizeJourney(journey)

        #expect(sanitized.shopPayloads[completedStage] == nil)
        #expect(sanitized.shopPayloads[activeStage] == Data([0x03, 0x04]))
    }

    @Test func `reachable node ID set matches reachable node IDs`() {
        var state = PlayerLabyrinthState.freshStart
        state.ensureMap(seed: 12345)
        #expect(state.hasMap)

        let set = state.reachableNodeIDSet()
        let list = state.reachableNodeIDs()

        #expect(set == Set(list))
        #expect(!set.isEmpty)

        for nodeID in set {
            #expect(state.isNodeReachable(nodeID))
        }

        for (id, node) in state.nodes where !set.contains(id) {
            #expect(!state.isNodeReachable(node.id))
        }
    }

    @Test func `reward ownership single pass matches property queries`() throws {
        let sword = try #require(GameContent.itemTemplate(matching: "longsword-basic"))
        let ring = try #require(GameContent.itemTemplate(matching: "ruby_ring-basic"))
        let trinket = try #require(GameContent.trinketItems.first)

        let stage = try #require(GameContent.stages.first)
        var inventory = PlayerInventoryState.freshStart
        inventory.addRewardItem(from: sword, for: stage)
        inventory.addRewardItem(from: ring, for: stage)
        inventory.appendUniqueItem(trinket)

        let ownership = RewardOwnership(inventory)

        #expect(ownership.ownedTrinketIDs == inventory.ownedTrinketIDs)
        #expect(ownership.ownedUniqueIDs == inventory.ownedUniqueIDs)
        #expect(ownership.ownedTrinketIDs.contains(trinket.templateID))
    }

    @Test func `contracts ensureBoard generates unique enemies in difficulty order`() {
        var contracts = PlayerContractsState.freshStart
        contracts.ensureBoard()

        #expect(contracts.offers.count == ContractDifficulty.allCases.count)
        for (index, difficulty) in ContractDifficulty.allCases.enumerated() {
            #expect(contracts.offers[index].difficulty == difficulty)
        }

        let enemyIDs = Set(contracts.offers.map(\.enemyID))
        #expect(enemyIDs.count == ContractDifficulty.allCases.count)

        contracts.refresh()
        #expect(contracts.offers.count == ContractDifficulty.allCases.count)
        let refreshedEnemyIDs = Set(contracts.offers.map(\.enemyID))
        #expect(refreshedEnemyIDs.count == ContractDifficulty.allCases.count)
    }

    @Test func `resolveStoreURL prioritizes explicit URL over name`() {
        let customURL = URL(fileURLWithPath: "/tmp/custom_test_path.store")
        let resolved = PlayerSaveStoreConfiguration.resolveStoreURL(storeName: "ignoredName", storeURL: customURL)
        #expect(resolved == customURL)

        let resolvedNamed = PlayerSaveStoreConfiguration.resolveStoreURL(storeName: "specificName", storeURL: nil)
        #expect(resolvedNamed.lastPathComponent == "specificName.store")
    }
}
