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

    @Test func `player combatants have complete ability choices and loadouts`() throws {
        for combatant in GameContent.combatants {
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
        for combatant in GameContent.combatants {
            try #expect(combatant.maxHealth >= 6, "\(combatant.name) should have at least 6 health")
            try #expect(combatant.maxMana >= 0, "\(combatant.name) should have non-negative mana")
        }
    }
}
