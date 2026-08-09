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

    @Test func fourthTierHomesteadEffectsUseUpgradedValues() throws {
        let effects = HomesteadEffects.from(
            nodeTiers: Dictionary(uniqueKeysWithValues: GameContent.homesteadNodes.map { ($0.id, 4) })
        )

        try #expect(effects.heroModifiers == [
            .maximumHealth(16),
            .healthRestored(4),
            .strength(8),
            .toughness(8),
            .damageTakenPercent(.burn, 0.4),
            .damageDealt(.physical, 4),
            .damageTakenPercent(.freeze, 0.5),
            .poisonDamageDealtPercent(0.2),
            .damageTakenPercent(.poison, 0.4),
            .maximumMana(8),
            .damageDealt(.burn, 4),
            .damageDealt(.freeze, 4),
            .damageDealt(.holy, 4),
            .companionDamageDealt(4),
        ])
        try #expect(effects.companionModifiers == [
            .maximumHealth(16),
            .healthRestored(4),
            .strength(8),
            .toughness(8),
            .damageTakenPercent(.burn, 0.4),
            .damageDealt(.physical, 4),
            .damageTakenPercent(.freeze, 0.5),
            .poisonDamageDealtPercent(0.2),
            .damageTakenPercent(.poison, 0.4),
            .maximumMana(8),
            .damageDealt(.burn, 4),
            .damageDealt(.freeze, 4),
            .damageDealt(.holy, 4),
            .agility(8),
        ])
        try #expect(effects.astralChanceBonusPercent == 20)
        try #expect(effects.goldFindPercent == 20)
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
