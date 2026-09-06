import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct TalentPersistenceTests {
    @Test @MainActor func `talent loadouts survive player save store round trip`() throws {
        let context = try PersistenceTestContext()
        let firstStore = try context.makeSaveStore()
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

        let secondStore = try context.makeReloadedStore()

        #expect(secondStore.currentSave.roster.unlockedTalents["knight"] == knightTalents)
        #expect(secondStore.currentSave.roster.unlockedTalents["rogue"] == rogueTalents)
    }

    @Test(arguments: ["knight", "alchemist", "druid", "wildcard"])
    @MainActor func `talent purchase survives reload`(combatantID: String) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        try store.performBatchMutation { save in
            save.roster.progressions[combatantID] = .at(level: 2)
        }
        let tree = try #require(CombatantTalentCatalog.allConfigs[combatantID]?.trees.first)
        let node = try #require(tree.nodes.first)

        #expect(store.unlockTalent(nodeID: node.id, treeID: tree.id, for: combatantID) == .unlocked)

        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.unlockedTalents(for: combatantID) == [node.id])
    }

    @Test @MainActor func `in-memory store rejects unavailable talent without mutation`() throws {
        let store = try PlayerSaveStore(inMemoryOnly: true, persistSaveImmediately: true)
        let knightTree = try #require(CombatantTalentCatalog.allConfigs["knight"]?.trees.first)
        let knightNode = try #require(knightTree.nodes.first)
        let rogueTree = try #require(CombatantTalentCatalog.allConfigs["rogue"]?.trees.first)

        #expect(
            store.unlockTalent(
                nodeID: knightNode.id,
                treeID: knightTree.id,
                for: "knight",
            ) == .unavailable,
        )
        #expect(
            store.unlockTalent(
                nodeID: knightNode.id,
                treeID: rogueTree.id,
                for: "knight",
            ) == .unavailable,
        )
        #expect(store.roster.unlockedTalents(for: "knight").isEmpty)
    }

    #if DEBUG
    @Test @MainActor func `in-memory failed talent save rolls back unlock`() throws {
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
                for: "knight",
            ) == .persistenceFailed,
        )
        #expect(store.roster.unlockedTalents(for: "knight").isEmpty)
    }
    #endif
}
