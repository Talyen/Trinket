import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct PlayerSaveSanitizerAbilityMigrationTests {
    @Test func `migrates legacy lizard scout steal ultimate to skill`() throws {
        let loadouts = RosterHydration.resolveAbilityLoadouts(from: [
            "lizard_scout": RosterHydration.AbilityLoadoutIDs(
                basicID: "stab",
                skillID: "poison-dagger",
                ultimateID: "steal",
            ),
        ])
        let loadout = try #require(loadouts["lizard_scout"])

        try #expect(loadout.basic?.id == "stab")
        try #expect(loadout.skill?.id == "steal")
        try #expect(loadout.ultimate?.id == "hemorrhage")
    }
}
