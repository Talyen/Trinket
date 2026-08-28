import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct TalentPersistenceTests {
    @Test func saveSanitizerFiltersInvalidCombatantsAndTalents() {
        var roster = PlayerRosterState.freshStart
        roster.progressions["knight"] = .at(level: 2)
        roster.unlockedTalents["knight"] = ["knight_block_t1_1", "invalid_node_id"]
        roster.unlockedTalents["invalid_combatant"] = ["some_node"]

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)
        #expect(sanitized.unlockedTalents["knight"] == ["knight_block_t1_1"])
        #expect(sanitized.unlockedTalents["invalid_combatant"] == nil)
    }

    @Test @MainActor func talentLoadoutsSurvivePlayerSaveStoreRoundTrip() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let knightTalents: Set = ["knight_block_t1_1", "knight_holy_t1_1"]
        let rogueTalents: Set = ["rogue_poison_t1_1", "rogue_poison_t1_2"]

        _ = firstStore.persistBatch(logging: "Persist talents") { save in
            save.roster.progressions["knight"] = .at(level: 4)
            save.roster.progressions["rogue"] = .at(level: 4)
            save.roster.unlockedTalents["knight"] = knightTalents
            save.roster.unlockedTalents["rogue"] = rogueTalents
        }

        #expect(firstStore.currentSave.roster.unlockedTalents["knight"] == knightTalents)
        #expect(firstStore.currentSave.roster.unlockedTalents["rogue"] == rogueTalents)

        let secondStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true
        )

        #expect(secondStore.currentSave.roster.unlockedTalents["knight"] == knightTalents)
        #expect(secondStore.currentSave.roster.unlockedTalents["rogue"] == rogueTalents)
    }

    @Test @MainActor func unlockingTalentThroughStoreSurvivesReload() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let store = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true,
            persistSaveImmediately: true
        )
        try store.performBatchMutation { save in
            save.roster.progressions["knight"] = .at(level: 2)
        }
        let tree = try #require(CombatantTalentCatalog.allConfigs["knight"]?.trees.first)
        let node = try #require(tree.nodes.first)

        #expect(store.unlockTalent(nodeID: node.id, treeID: tree.id, for: "knight") == .unlocked)

        let reloaded = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        #expect(reloaded.roster.unlockedTalents(for: "knight") == [node.id])
    }

    @Test @MainActor func storeRejectsUnavailableTalentWithoutMutation() throws {
        let store = try PlayerSaveStore(inMemoryOnly: true, persistSaveImmediately: true)
        let knightTree = try #require(CombatantTalentCatalog.allConfigs["knight"]?.trees.first)
        let knightNode = try #require(knightTree.nodes.first)
        let rogueTree = try #require(CombatantTalentCatalog.allConfigs["rogue"]?.trees.first)

        #expect(
            store.unlockTalent(
                nodeID: knightNode.id,
                treeID: knightTree.id,
                for: "knight"
            ) == .unavailable
        )
        #expect(
            store.unlockTalent(
                nodeID: knightNode.id,
                treeID: rogueTree.id,
                for: "knight"
            ) == .unavailable
        )
        #expect(store.roster.unlockedTalents(for: "knight").isEmpty)
    }

    #if DEBUG
    @Test @MainActor func failedTalentSaveRollsBackUnlock() throws {
        let store = try PlayerSaveStore(inMemoryOnly: true, persistSaveImmediately: true)
        try store.performBatchMutation { save in
            save.roster.progressions["knight"] = .at(level: 2)
        }
        let tree = try #require(CombatantTalentCatalog.allConfigs["knight"]?.trees.first)
        let node = try #require(tree.nodes.first)
        store.forcesNextSaveFailure = true

        #expect(
            store.unlockTalent(
                nodeID: node.id,
                treeID: tree.id,
                for: "knight"
            ) == .persistenceFailed
        )
        #expect(store.roster.unlockedTalents(for: "knight").isEmpty)
    }
    #endif
}
