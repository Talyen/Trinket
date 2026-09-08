import Testing
import TrinketContent
import TrinketCore
@testable import TrinketFeatureAdapters

struct ItemPickerItemsTests {
    @Test func `search combines fields and filters`() {
        let item = makeItem("match", name: "Étoile", rarity: .astral, keyword: .burn)
        var model = ItemPickerItems()
        model.update(inventory: [item, makeItem("other", rarity: .basic)], loadout: .init(), slot: .weapon)
        let filter = ItemPickerFilter(search: "  ETOILE sword flame damage BURN \n", rarity: .astral, keyword: .burn)
        #expect(model.matching(filter).map(\.id) == [item.id])
        #expect(model.matching(ItemPickerFilter(search: "etoile missing")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "etoile", rarity: .unique)).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "etoile", keyword: .poison)).isEmpty)
        #expect(model.keywords == [.burn, .physical])
        #expect(!model.keywords.contains(.poison))
    }

    @Test func `filter active state handles empty and trimmed whitespace`() {
        #expect(!ItemPickerFilter().isActive)
        #expect(!ItemPickerFilter(search: "   \n\t  ").isActive)
        #expect(ItemPickerFilter(search: "sword").isActive)
        #expect(ItemPickerFilter(rarity: .astral).isActive)
        #expect(ItemPickerFilter(keyword: .burn).isActive)
    }

    @Test func `order is deterministic and stable during visit`() {
        let items = [
            makeItem("z", rarity: .astral), makeItem("b", rarity: .unique),
            makeItem("equipped", rarity: .basic), makeItem("a", rarity: .astral),
        ]
        var model = ItemPickerItems()
        model.update(inventory: items, loadout: .init(itemIDsBySlot: [.weapon: "equipped"]), slot: .weapon)
        #expect(model.eligible.map(\.id) == ["equipped", "b", "a", "z"])
        #expect(model.matching(ItemPickerFilter(rarity: .astral)).map(\.id) == ["a", "z"])
        model.update(inventory: items.reversed(), loadout: .init(itemIDsBySlot: [.weapon: "z"]), slot: .weapon)
        #expect(model.eligible.map(\.id) == ["equipped", "b", "a", "z"])
        var nextVisit = ItemPickerItems()
        nextVisit.update(inventory: items, loadout: .init(itemIDsBySlot: [.weapon: "z"]), slot: .weapon)
        #expect(nextVisit.eligible.map(\.id) == ["z", "b", "a", "equipped"])
    }

    @Test func `inventory changes refresh search and eligibility`() {
        var model = ItemPickerItems()
        model.update(inventory: [makeItem("same", name: "Old")], loadout: .init(), slot: .weapon)
        model.update(inventory: [makeItem("same", name: "New", keyword: .burn)], loadout: .init(), slot: .weapon)
        #expect(model.matching(ItemPickerFilter(search: "old")).isEmpty)
        #expect(model.matching(ItemPickerFilter(search: "new", keyword: .burn)).count == 1)
        model.update(inventory: [makeItem("same")], loadout: .init(), slot: .armor)
        #expect(model.eligible.isEmpty)
        #expect(model.keywords.isEmpty)
    }

    @Test(arguments: [50, 200, 500])
    func `large inventories retain distinct instances`(count: Int) {
        let items = (0 ..< count).map { makeItem("item-\($0)", rarity: $0.isMultiple(of: 2) ? .astral : .basic) }
        var model = ItemPickerItems()
        model.update(inventory: items, loadout: .init(), slot: .weapon)
        #expect(Set(model.eligible.map(\.id)).count == count)
        #expect(model.matching(ItemPickerFilter(search: "sword", rarity: .astral)).count == count / 2)
    }

    private func makeItem(
        _ id: String,
        name: String = "Sword",
        rarity: Rarity = .basic,
        keyword: Keyword = .physical,
    ) -> InventoryItem {
        InventoryItem(
            id: id,
            baseType: ItemBaseType(id: "sword", name: "Sword", slot: .weapon, weaponKind: .oneHanded, keywordAffinities: [.poison]),
            rarity: rarity,
            displayName: name,
            affixes: [ItemAffix(id: "picker-fixture", title: "Flame", description: "Deal damage.", keywords: [keyword])],
        )
    }
}
