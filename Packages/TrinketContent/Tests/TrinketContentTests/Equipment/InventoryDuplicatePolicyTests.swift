import Testing
import TrinketContent

struct InventoryDuplicatePolicyTests {
    @Test func `rejected inventory records cannot reserve another ownership key`() throws {
        let unique = try #require(GameContent.unique(matching: "wardbreaker"))
        let trinket = try #require(GameContent.trinketItems.first)
        // Current-data repair can encounter conflicting rarity and base fields.
        // This record conflicts with the retained Unique but also has a Trinket key.
        let rejected = InventoryItem(
            id: "rejected-hybrid", templateID: unique.templateID, baseType: trinket.baseType,
            rarity: .unique, displayName: trinket.displayName, affixes: trinket.affixes,
        )
        let survivor = InventoryItem(
            id: "surviving-trinket", templateID: unique.templateID, baseType: trinket.baseType,
            rarity: .astral, displayName: trinket.displayName, affixes: trinket.affixes,
        )
        let items = [unique, rejected, survivor]
        let repaired = InventoryDuplicatePolicy.deduplicated(items)
        #expect(repaired == [unique, survivor])

        var batched = [unique]
        InventoryDuplicatePolicy.appendUniqueItems([rejected, survivor, survivor], to: &batched)
        #expect(batched == repaired)
    }
}
