import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
struct TalentPersistenceTests {
    @Test func playerRosterStateTracksAndUnlocksTalents() throws {
        var roster = PlayerRosterState.freshStart
        roster.progressions["rogue"] = CombatantProgression.at(level: 5) // 4 total points

        let config = CombatantTalentCatalog.config(for: "rogue")
        let venomTree = try #require(config.tree(for: .poison))
        let t1Nodes = venomTree.nodes(forTier: 1)
        let t2Nodes = venomTree.nodes(forTier: 2)

        #expect(roster.availableTalentPoints(for: "rogue") == 4)
        #expect(roster.unlockedTalents(for: "rogue").isEmpty)

        // Cannot unlock Tier 2 before Tier 1
        let unlockedT2Direct = roster.unlockTalent(node: t2Nodes[0], inTree: venomTree, for: "rogue")
        #expect(!unlockedT2Direct)

        // Unlock all 2 Tier 1 nodes
        let u1 = roster.unlockTalent(node: t1Nodes[0], inTree: venomTree, for: "rogue")
        let u2 = roster.unlockTalent(node: t1Nodes[1], inTree: venomTree, for: "rogue")
        #expect(u1 && u2)

        #expect(roster.availableTalentPoints(for: "rogue") == 2)
        #expect(roster.unlockedTalents(for: "rogue").count == 2)

        // Now Tier 2 can be unlocked
        let u3 = roster.unlockTalent(node: t2Nodes[0], inTree: venomTree, for: "rogue")
        #expect(u3)
        #expect(roster.availableTalentPoints(for: "rogue") == 1)

        // Reset talents
        roster.resetTalents(for: "rogue")
        #expect(roster.unlockedTalents(for: "rogue").isEmpty)
        #expect(roster.availableTalentPoints(for: "rogue") == 4)
    }

    @Test func saveSanitizerPreservesTalents() {
        var roster = PlayerRosterState.freshStart
        roster.unlockedTalents["knight"] = ["knight_block_t1_1", "knight_holy_t1_1"]

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)
        #expect(sanitized.unlockedTalents["knight"] == ["knight_block_t1_1", "knight_holy_t1_1"])
    }

    @Test func saveSanitizerFiltersInvalidCombatantsAndTalents() {
        var roster = PlayerRosterState.freshStart
        roster.unlockedTalents["knight"] = ["knight_block_t1_1", "invalid_node_id"]
        roster.unlockedTalents["invalid_combatant"] = ["some_node"]

        let sanitized = PlayerSaveSanitizer.sanitizeRoster(roster, inventory: .freshStart)
        #expect(sanitized.unlockedTalents["knight"] == ["knight_block_t1_1"])
        #expect(sanitized.unlockedTalents["invalid_combatant"] == nil)
    }

    @Test func talentLoadoutsSurvivePlayerSaveStoreRoundTrip() throws {
        let context = try PersistenceTestContext()
        let storeURL = context.storeURL()
        let firstStore = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true, persistSaveImmediately: true)
        let knightTalents: Set = ["knight_block_t1_1", "knight_holy_t1_1"]
        let rogueTalents: Set = ["rogue_poison_t1_1", "rogue_poison_t1_2"]

        _ = firstStore.persistBatch(logging: "Persist talents") { save in
            save.roster.unlockedTalents["knight"] = knightTalents
            save.roster.unlockedTalents["rogue"] = rogueTalents
        }

        #expect(firstStore.currentSave.roster.unlockedTalents["knight"] == knightTalents)
        #expect(firstStore.currentSave.roster.unlockedTalents["rogue"] == rogueTalents)

        // Reload fresh store from the same underlying store URL
        let secondStore = try PlayerSaveStore(
            storeURL: storeURL,
            disableCloudSync: true
        )

        #expect(secondStore.currentSave.roster.unlockedTalents["knight"] == knightTalents)
        #expect(secondStore.currentSave.roster.unlockedTalents["rogue"] == rogueTalents)
    }
}
