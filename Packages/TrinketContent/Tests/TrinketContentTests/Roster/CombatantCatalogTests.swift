import Testing
import TrinketContent
import TrinketCore

struct CombatantCatalogTests {
    @Test func `player combatants have complete ability choices and loadouts`() throws {
        for combatant in GameContent.combatants {
            for tier in AbilityTier.allCases {
                let choices = combatant.abilityChoices.abilities(for: tier)
                try #expect(choices.count == 4, "\(combatant.name) should have four \(tier.rawValue) choices")
                try #expect(Set(choices.map(\.id)).count == 4)
                try #expect(choices.allSatisfy { $0.tier == tier })
                let selected = try #require(
                    combatant.abilityLoadout.ability(for: tier),
                    "\(combatant.name) needs a selected \(tier.rawValue)",
                )
                #expect(choices.contains(selected), "\(combatant.name) selected \(tier.rawValue) must match a complete authored choice")
            }
        }
    }

    @Test func `player combatants have valid health and mana`() throws {
        for combatant in GameContent.combatants {
            try #expect(combatant.maxHealth >= 6, "\(combatant.name) should have at least 6 health")
            try #expect(combatant.maxMana >= 0, "\(combatant.name) should have non-negative mana")
        }
    }
}
