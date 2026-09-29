import Testing
import TrinketContent

struct HiddenCacheCompatibilityTests {
    @Test func `saved Hidden Cache replaces victory Gold and preserves unrelated powers`() throws {
        let current = try #require(GameContent.itemAffixDefinition(matching: "smugglers_map"))
        let old = ItemAffixPower(
            description: "Gain 4 additional Gold on victory.", modifiers: [.maximumHealth(6)],
            triggers: CombatTraitTriggers(gold: GoldTriggers(goldPerTurn: 2, victoryGoldFlat: 4)),
        )
        let template = try #require(GameContent.trinketItems.first { $0.templateID == "smugglers_map" })
        let saved = InventoryItem(
            id: "saved-map", templateID: template.templateID, baseType: template.baseType,
            rarity: template.rarity, displayName: template.displayName,
            affixes: template.affixes, affixPowers: [old],
        )
        let resolved = try #require(saved.resolvedPower(at: 0))
        #expect(resolved.triggers.victoryGoldFlat == 0)
        #expect(resolved.triggers.goldTheftDrawChancePercent == 0.20)
        #expect(resolved.triggers.goldPerTurn == 2)
        #expect(resolved.modifiers == old.modifiers)
        #expect(resolved.description == current.power(for: template.rarity).description)
    }
}
