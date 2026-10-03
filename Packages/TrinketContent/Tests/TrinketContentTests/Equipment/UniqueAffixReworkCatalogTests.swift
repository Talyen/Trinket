import Testing
import TrinketContent

struct UniqueAffixReworkCatalogTests {
    @Test(arguments: ["red_harvest", "huntsmasters_call", "threefold_grace", "golden_verdict"])
    func `owned Uniques resolve reworked signatures from older powers`(id: String) throws {
        let current = try #require(GameContent.unique(matching: id))
        var powers = try #require(current.affixPowers)
        var oldTriggers = CombatTraitTriggers()
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
    }
}
