import Testing
import TrinketContent

struct UniqueAffixReworkCatalogTests {
    @Test(arguments: ["red_harvest", "huntsmasters_call", "threefold_grace", "golden_verdict", "vipers_courtesy"])
    func `owned Uniques resolve reworked signatures from older powers`(id: String) throws {
        let current = try #require(GameContent.unique(matching: id))
        var powers = try #require(current.affixPowers)
        var oldTriggers = id == "vipers_courtesy" ? powers[0].triggers : CombatTraitTriggers()
        if id == "golden_verdict" {
            oldTriggers.holyStunBuildupPercent = 1
            oldTriggers.holyTriggeredStunGoldFlat = 1
        }
        powers[0] = ItemAffixPower(description: "Older signature", modifiers: [], triggers: oldTriggers)
        let owned = InventoryItem(
            id: "saved-\(id)", templateID: id, baseType: current.baseType,
            rarity: .unique, displayName: current.displayName,
            affixes: current.affixes, affixPowers: powers,
        )
        let restored = try #require(owned.resolvedPower(at: 0))
        #expect(restored == current.resolvedPower(at: 0))
        if id == "vipers_courtesy" {
            #expect(restored.description.contains("manually played card hit that removes Health"))
            #expect(owned.displayedAffixes.first?.description == restored.description)
        }
    }
}
