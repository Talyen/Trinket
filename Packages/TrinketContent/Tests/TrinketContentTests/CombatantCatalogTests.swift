import Testing
import TrinketContent

struct CombatantCatalogTests {
    @Test func homesteadNodeIDsAreUnique() throws {
        let ids = GameContent.homesteadNodes.map(\.id)
        try #expect(Set(ids).count == ids.count)
    }

    @Test func homesteadPrerequisitesReferenceKnownNodes() throws {
        let knownIDs = Set(GameContent.homesteadNodes.map(\.id))
        for node in GameContent.homesteadNodes {
            for requirement in node.prerequisites {
                try #expect(
                    knownIDs.contains(requirement.nodeID),
                    "Node \(node.id) references unknown prerequisite \(requirement.nodeID)"
                )
            }
        }
    }

    @Test func playerCombatantsHaveCompleteAbilityChoicesAndLoadouts() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            try #expect(!combatant.abilityChoices.basics.isEmpty, "\(combatant.name) should have basic choices")
            try #expect(!combatant.abilityChoices.skills.isEmpty, "\(combatant.name) should have skill choices")
            try #expect(!combatant.abilityChoices.ultimates.isEmpty, "\(combatant.name) should have ultimate choices")
            _ = try #require(combatant.abilityLoadout.basic, "\(combatant.name) should have a selected basic")
            _ = try #require(combatant.abilityLoadout.skill, "\(combatant.name) should have a selected skill")
            _ = try #require(combatant.abilityLoadout.ultimate, "\(combatant.name) should have a selected ultimate")
        }
    }

    @Test(arguments: GameContent.heroes + GameContent.companions)
    func playerCombatantsUseBaselinePrimaryStatBudget(combatant: Combatant) throws {
        let stats = combatant.primaryStats
        let total = stats.strength + stats.agility + stats.toughness + stats.intellect + stats.wisdom
        try #expect(total == 50, "\(combatant.name) primary stats should sum to 50, got \(total)")
    }
}
