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

    @Test func homesteadNodesHaveFourthTier() throws {
        for node in GameContent.homesteadNodes {
            try #expect(node.maxTier == 4, "\(node.title) should have four tiers")
        }
    }

    @Test func homesteadTiersStrengthenEffectsAndStayPartyScoped() throws {
        for node in GameContent.homesteadNodes {
            let nodeID = node.id
            let tier1 = HomesteadEffects.from(nodeTiers: [nodeID: 1])
            let tier4 = HomesteadEffects.from(nodeTiers: [nodeID: 4])
            switch nodeID {
            case .moonlitSanctum:
                try #expect(tier1.astralChanceBonusPercent == 5)
                try #expect(tier4.astralChanceBonusPercent == 20)
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.isEmpty)
            case .wishingWell:
                try #expect(tier1.goldFindPercent == 5)
                try #expect(tier4.goldFindPercent == 20)
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.isEmpty)
            case .hunterLodge:
                try #expect(tier1.companionModifiers.isEmpty)
                try #expect(tier4.companionModifiers.isEmpty)
                try #expect(tier1.heroModifiers.count == 1)
                try #expect(tier4.heroModifiers.count == 1)
                try #expect(tier4.heroModifiers[0].numericValue > tier1.heroModifiers[0].numericValue)
            case .agilityTraining:
                try #expect(tier1.heroModifiers.isEmpty)
                try #expect(tier4.heroModifiers.isEmpty)
                try #expect(tier1.companionModifiers.count == 1)
                try #expect(tier4.companionModifiers.count == 1)
                try #expect(
                    tier4.companionModifiers[0].numericValue > tier1.companionModifiers[0].numericValue
                )
            default:
                try #expect(tier1.heroModifiers == tier1.companionModifiers)
                try #expect(tier4.heroModifiers == tier4.companionModifiers)
                try #expect(!tier1.heroModifiers.isEmpty)
                try #expect(tier1.heroModifiers.count == tier4.heroModifiers.count)
                for (lower, higher) in zip(tier1.heroModifiers, tier4.heroModifiers) {
                    try #expect(higher.numericValue > lower.numericValue)
                }
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

    @Test func playerCombatantsUseBaselinePrimaryStatBudget() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            let stats = combatant.primaryStats
            let total = stats.strength + stats.agility + stats.toughness + stats.intellect + stats.wisdom
            try #expect(total == 50, "\(combatant.name) primary stats should sum to 50, got \(total)")
        }
    }
}
