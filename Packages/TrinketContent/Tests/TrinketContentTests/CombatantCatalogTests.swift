import Testing
import TrinketContent
import TrinketCore

struct CombatantCatalogTests {
    @Test(arguments: [
        ("alchemist", 14, 8, ["caustic-jab", "acid-potion", "luck-potion"]),
        ("druid", 16, 9, ["mana-berries", "cinderbloom", "bloodthorn"]),
        ("wildcard", 14, 0, ["blackjack", "bounty-shot", "astral-arrow"]),
    ])
    func `imported heroes have approved defaults`(id: String, health: Int, mana: Int, abilities: [String]) throws {
        let hero = try #require(GameContent.heroes.first { $0.id == id })
        #expect(hero.maxHealth == health && hero.maxMana == mana)
        #expect(hero.abilityLoadout.abilities.map(\.id) == abilities)
        let config = CombatantTalentCatalog.config(for: id)
        #expect(config.trees.allSatisfy { $0.nodes.count == 7 && $0.nodes(forRow: 4).count == 1 })
        let art = try #require(ArtCatalog.combatantArtByID[id])
        #expect(art.imageName == "hero_\(id)_card")
        #expect(art.thumbnailImageName == "hero_\(id)_card_thumb")
    }

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
        #expect(agility.companionModifiers == [.dodgeChanceBonus(0.04)])
    }

    @Test func `player combatants have complete ability choices and loadouts`() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            for tier in AbilityTier.allCases {
                let choices = combatant.abilityChoices.abilities(for: tier)
                try #expect(choices.count == 4, "\(combatant.name) should have four \(tier.rawValue) choices")
                try #expect(Set(choices.map(\.id)).count == 4)
                try #expect(choices.allSatisfy { $0.tier == tier })
                try #expect(combatant.abilityLoadout.ability(for: tier)?.id == choices.first?.id)
            }
            _ = try #require(combatant.abilityLoadout.basic, "\(combatant.name) should have a selected basic")
            _ = try #require(combatant.abilityLoadout.skill, "\(combatant.name) should have a selected skill")
            _ = try #require(combatant.abilityLoadout.ultimate, "\(combatant.name) should have a selected ultimate")
        }
    }

    @Test func `player combatants have valid health and mana`() throws {
        for combatant in GameContent.heroes + GameContent.companions {
            try #expect(combatant.maxHealth >= 6, "\(combatant.name) should have at least 6 health")
            try #expect(combatant.maxMana >= 0, "\(combatant.name) should have non-negative mana")
        }
    }
}
