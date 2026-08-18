import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
struct TalentPersistenceTests {
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
