import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct InventoryModelMappingTests {
    @Test func persistedTrinketRefreshesFromAuthoredCatalog() throws {
        let staleItem = InventoryItemModel()
        staleItem.id = "owned-meteorite"
        staleItem.templateID = "meteorite"
        staleItem.baseTypeID = "meteorite"
        staleItem.rarityID = Rarity.basic.rawValue
        staleItem.displayName = "Dormant Meteorite"
        staleItem.affixes = [ItemAffixModel(affix: ItemAffix(
            id: "dormant_meteorite",
            title: "Dormant",
            description: "Placeholder.",
            keywords: [.burn]
        ))]
        let model = InventoryModel()
        model.items = [staleItem]

        let restored = try #require(model.toPlayerInventoryState().items.first)
        let authored = try #require(GameContent.itemTemplate(matching: "meteorite"))

        #expect(restored.id == "owned-meteorite")
        #expect(restored.rarity == .astral)
        #expect(restored.displayName == authored.displayName)
        #expect(restored.affixes == authored.affixes)
    }
}
