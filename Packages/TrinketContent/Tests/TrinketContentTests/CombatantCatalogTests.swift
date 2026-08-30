import Testing
import TrinketContent
import TrinketCore

struct CombatantCatalogTests {
    @Test func `homestead node I ds are unique`() throws {
        let ids = GameContent.homesteadNodes.map(\.id)
        try #expect(Set(ids).count == ids.count)
    }

    @Test func `homestead prerequisites reference known nodes`() throws {
        let knownIDs = Set(GameContent.homesteadNodes.map(\.id))
        for node in GameContent.homesteadNodes {
            for requirement in node.prerequisites {
                try #expect(
                    knownIDs.contains(requirement.nodeID),
                    "Node \(node.id) references unknown prerequisite \(requirement.nodeID)",
                )
            }
        }
    }

    @Test func `homestead tiers strengthen effects and stay party scoped`() throws {
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
                    tier4.companionModifiers[0].numericValue > tier1.companionModifiers[0].numericValue,
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

    @Test func `homestead combat bonuses match authored tier values`() {
        let culinary = HomesteadEffects.from(nodeTiers: [.culinaryArts: 1])
        #expect(culinary.heroModifiers == [.damageTakenPercent(.burn, 0.10)])
        #expect(culinary.companionModifiers == culinary.heroModifiers)

        let culinaryMax = HomesteadEffects.from(nodeTiers: [.culinaryArts: 4])
        #expect(culinaryMax.heroModifiers == [.damageTakenPercent(.burn, 0.40)])

        let wool = HomesteadEffects.from(nodeTiers: [.woolTailoring: 1])
        #expect(wool.heroModifiers == [.damageTakenPercent(.freeze, 0.15)])
        let woolMax = HomesteadEffects.from(nodeTiers: [.woolTailoring: 4])
        #expect(woolMax.heroModifiers == [.damageTakenPercent(.freeze, 0.5)])

        let alchemy = HomesteadEffects.from(nodeTiers: [.alchemyLab: 1])
        #expect(alchemy.heroModifiers == [
            .poisonDamageDealtPercent(0.05),
            .damageTakenPercent(.poison, 0.10),
        ])
        #expect(alchemy.companionModifiers == alchemy.heroModifiers)

        let lodge = HomesteadEffects.from(nodeTiers: [.hunterLodge: 4])
        #expect(lodge.heroModifiers == [.companionDamageDealt(4)])
        #expect(lodge.companionModifiers.isEmpty)

        let agility = HomesteadEffects.from(nodeTiers: [.agilityTraining: 2])
        #expect(agility.heroModifiers.isEmpty)
        #expect(agility.companionModifiers == [.agility(4)])
    }

    @Test func `player combatants have complete ability choices and loadouts`() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            try #expect(!combatant.abilityChoices.basics.isEmpty, "\(combatant.name) should have basic choices")
            try #expect(!combatant.abilityChoices.skills.isEmpty, "\(combatant.name) should have skill choices")
            try #expect(!combatant.abilityChoices.ultimates.isEmpty, "\(combatant.name) should have ultimate choices")
            _ = try #require(combatant.abilityLoadout.basic, "\(combatant.name) should have a selected basic")
            _ = try #require(combatant.abilityLoadout.skill, "\(combatant.name) should have a selected skill")
            _ = try #require(combatant.abilityLoadout.ultimate, "\(combatant.name) should have a selected ultimate")
        }
    }

    @Test func `player combatants use baseline primary stat budget`() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            let stats = combatant.primaryStats
            let total = stats.strength + stats.agility + stats.toughness + stats.intellect + stats.wisdom
            try #expect(total == 50, "\(combatant.name) primary stats should sum to 50, got \(total)")
        }
    }
}
